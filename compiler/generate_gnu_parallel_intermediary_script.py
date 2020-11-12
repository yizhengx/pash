import sys
import os
import subprocess
from shutil import copyfile, rmtree
from generate_microbenchmark_intermediary_scripts import list_split_inputs, generate_env_file, replace_in_variable

def generate_gnu_parallel_script(input_script, output_script, new_input_files):
    ## Generate the sequential script
    with open(input_script) as file:
        input_script_data = file.read()

    output_script_data = replace_in_variable(input_script_data, new_input_files)
    output_script_data = replace_temp_variable(output_script_data, new_input_files)

    ## TODO: Also create the TEMP_C variable instead of having it fixed in the script

    with open(output_script, "w") as file:
        file.write(output_script_data)

def replace_temp_variable(data, new_input_files):
    print(new_input_files)
    filenames = [filename.split("/")[-1] 
                 for filename in new_input_files]
    format_string = "/tmp/{}.out"
    new_data = data.replace(' ${TEMP}', ' ' + ' '.join([format_string.format(filename)
                                                    for filename in filenames]))
    return new_data


input_script_dir = sys.argv[1]
input_env_dir = sys.argv[2]
name_of_script = sys.argv[3]
number_of_inputs = int(sys.argv[4])
output_dir = sys.argv[5]

try:
    env_suffix = sys.argv[6]
except:
    env_suffix = "env"

## This script takes a microbenchmark script as input, finds the $IN
## occurence in it and then generates an intermediary script with many
## $INs in its place.
input_script = os.path.join(input_script_dir, name_of_script + ".sh")
output_script = os.path.join(output_dir, '{}_{}_gnu_parallel.sh'.format(name_of_script, number_of_inputs))
input_env = os.path.join(input_env_dir, name_of_script + "_{}.sh".format(env_suffix))
output_env = os.path.join(output_dir, '{}_{}_gnu_parallel_env.sh'.format(name_of_script, number_of_inputs))
input_funs = os.path.join(input_env_dir, name_of_script + "_funs.sh")
output_funs = os.path.join(output_dir, '{}_{}_gnu_parallel_funs.sh'.format(name_of_script, number_of_inputs))

## Find and split input files given the environment file
new_input_files = list_split_inputs(output_dir)

## Generate new environment file
generate_env_file(input_env, output_env, new_input_files)

## Copy the funs file (if it exists)
if os.path.exists(input_funs):
    copyfile(input_funs, output_funs)

generate_gnu_parallel_script(input_script, output_script, new_input_files)
