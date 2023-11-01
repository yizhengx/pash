import argparse
from collections import defaultdict, deque
import logging
import pickle
from typing import Dict, List, Tuple
import sys
from uuid import UUID, uuid4

sys.path.append("/pash/compiler")
import definitions.ir.nodes.serverless_remote_pipe as serverless_remote_pipe
import definitions.ir.nodes.serverless_lambda_invoke as serverless_lambda_invoke
from definitions.ir.nodes.r_merge import RMerge
from dspash.ir_helper import split_ir
from ir_to_ast import to_shell
from ir import *
import config


def add_stdout_fid(graph : IR, file_id_gen: FileIdGen) -> FileId:
    stdout = file_id_gen.next_file_id()
    stdout.set_resource(FileDescriptorResource(('fd', 1)))
    graph.add_edge(stdout)
    return stdout

def add_nodes_to_subgraphs(subgraphs:List[IR], file_id_gen: FileIdGen, input_fifo_map:Dict[int, IR]):
    """ Takes a list of subgraphs and assigns a worker to each subgraph and augment
    the subgraphs with the necessary remote read/write nodes for data movement 
    between workers. This function also produces graph that should run in 
    the original shell in which pash was executed. This graph contains 
    remote read/write nodes for stdin/stdout, named pipes, and files.

    Args:
        subgraphs: list of sub sections of an optimized IR (returned from split_ir)
        file_id_gen: file id generator of the original ir
        input_fifo_map: mapping from input idge id to subgraph (returned from split_ir)
    Returns:
        main_graph_script_id: the script id to execute on main shell
        subgraph_script_id_pairs: mapping from subgraph to unique script id
        main_subgraph_script_id: the script id to execute in the first lambda
    """
    # The graph to execute in the main pash_compiler
    main_graph = IR({}, {})
    subgraph_script_id_pairs = {} 
    main_subgraph_script_id = None

    # Replace output edges and corrosponding input edges with remote read/write 
    # with the key as old_edge_id
    for subgraph in subgraphs:
        sink_nodes = subgraph.sink_nodes()
        assert(len(sink_nodes) == 1)
        out_edges = subgraph.get_node_output_fids(sink_nodes[0])
        # log("---> r_split_binary format:", r_split_binary_format)
        for out_edge in out_edges:            
            # Replace the old edge with an ephemeral edge in case it isn't and
            # to avoid modifying the edge in case it's used in some other subgraph
            out_edge_id = out_edge.get_ident()
            ephemeral_edge = file_id_gen.next_ephemeral_file_id()
            subgraph.replace_edge(out_edge_id, ephemeral_edge)
            edge_uid = uuid4()
            stdout = add_stdout_fid(subgraph, file_id_gen)
            last_subgraph = False
            # if no downstream subgraph, assuming this is the last subgraph
            # TODO: check if above assumption makes sense
            if out_edge_id not in input_fifo_map:
                last_subgraph = True
            # Add remote-write node at the end of the subgraph
            remote_write = serverless_remote_pipe.make_serverless_remote_pipe(ephemeral_edge.get_ident(), stdout.get_ident(), False, edge_uid, None, last_subgraph)
            subgraph.add_node(remote_write)
            
            # Copy the old output edge resource
            new_edge = file_id_gen.next_file_id()
            new_edge.set_resource(out_edge.get_resource())
            # Get the subgraph which "edge" writes to
            if out_edge_id in input_fifo_map and out_edge.is_ephemeral():
                matching_subgraph = input_fifo_map[out_edge_id][0]
                matching_subgraph.replace_edge(out_edge.get_ident(), new_edge)
                # Add invocation node
                # TODO: maybe use hashing or other identity to name the script
                if matching_subgraph not in subgraph_script_id_pairs:
                    script_identifier = uuid4()
                    subgraph_script_id_pairs[matching_subgraph] = script_identifier
                    subgraph.add_node(serverless_lambda_invoke.make_serverless_lambda_invoke(script_identifier))
            else:
                # Add edge to main graph
                matching_subgraph = main_graph
                matching_subgraph.add_edge(new_edge)
                
            remote_read = serverless_remote_pipe.make_serverless_remote_pipe(None, new_edge.get_ident(), True, edge_uid, out_resource=new_edge.get_resource())
            matching_subgraph.add_node(remote_read)
    
    # Replace non ephemeral input edges with remote read/write
    for subgraph in subgraphs:
        if subgraph not in subgraph_script_id_pairs:
            main_subgraph_script_id = uuid4()
            subgraph_script_id_pairs[subgraph] = main_subgraph_script_id
        source_nodes = subgraph.source_nodes()
        for source in source_nodes:
            if isinstance(subgraph.get_node(source), serverless_lambda_invoke.ServerlessLambdaInvoke) or \
                isinstance(subgraph.get_node(source), serverless_remote_pipe.ServerlessRemotePipe):
                continue
            for in_edge in subgraph.get_node_input_fids(source):
                # TODO: also consider in_edge.has_file_descriptor_resource()
                if in_edge.has_file_resource():
                    filename = in_edge.get_resource().uri

                    # Add remote read to current subgraph
                    ephemeral_edge = file_id_gen.next_ephemeral_file_id()
                    subgraph.replace_edge(in_edge.get_ident(), ephemeral_edge)
                    
                    remote_read = serverless_remote_pipe.make_serverless_remote_pipe(None, ephemeral_edge.get_ident(), True, filename)
                    subgraph.add_node(remote_read)
                else:
                    # sometimes a command can have both a file resource and an ephemeral resources (example: spell oneliner)
                    continue
    main_graph_script_id = uuid4()
    subgraph_script_id_pairs[main_graph] = main_graph_script_id
    return main_graph_script_id, subgraph_script_id_pairs, main_subgraph_script_id


def prepare_scripts_for_serverless_exec(ir: IR, shell_vars: dict, args: argparse.Namespace) -> Tuple[str, str, Dict[str, str]]:
    """
    Reads the complete ir from filename and splits it
    into subgraphs where ony the first subgraph represent a continues
    segment (merger segment or branched segment) in the graph. 
    Note: All subgraphs(except first one) read and write from remote pipes.
        However, we had to add a fake stdout to avoid some problems when converting to shell code.

    Returns: 
        sub_graph: List of (worker, subgraph)
        shell_vars: shell variables
        main_graph: The ir we need to execute on the main shell. 
            This graph contains edges to correctly redirect the following to remote workers
            - special pipes (stdin/stdout)
            - named pipes reading and writing
            - files reading and writing
    """
    # split IR
    subgraphs, mapping = split_ir(ir)
    main_graph_script_id, subgraph_script_id_pairs, main_subgraph_script_id = add_nodes_to_subgraphs(subgraphs, ir.get_file_id_gen(), mapping)

    # save the output scripts
    script_id_to_script = {}
    for subgraph, id_ in subgraph_script_id_pairs.items():
        dir_set = set()
        for edge in subgraph.all_fids():
            if edge.is_ephemeral():
                dir_set.add(os.path.join(config.PASH_TMP_PREFIX, edge.prefix))
        mk_dirs = "mkdir "+config.PASH_TMP_PREFIX+" \n"
        for dir in dir_set:
            mk_dirs += "mkdir "+dir+" \n"
        mk_dirs +=  "echo $1\n"
        script = mk_dirs+to_shell(subgraph, args)
        script_name = os.path.join(config.PASH_TMP_PREFIX, str(id_))
        script_id_to_script[str(id_)] = script
        with open (script_name, "w") as f:
            f.write(script)
        if id_ == main_graph_script_id:
            log("Script for main shell saved in:"+script_name)
        elif id_ == main_subgraph_script_id:
            log("Script for first lambda saved in:"+script_name)
        else:
            log("Script for other lambda saved in:"+script_name)
        # log(script)
        # log("-----------------")
    
    return str(main_graph_script_id), str(main_subgraph_script_id), script_id_to_script