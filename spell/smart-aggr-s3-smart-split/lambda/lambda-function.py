import subprocess


def lambda_handler(event, context):
    num = event["num"]
    data = event["data"]
    id = event["id"]
    script = f"scripts/script{num}.sh"

    process = subprocess.Popen(
        ["/bin/bash", script, num, data, id], stdout=subprocess.PIPE
    )

    process.wait()

    output, _ = process.communicate()

    return output
