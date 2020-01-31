import paramiko
import argparse
import sys
import time

parser = argparse.ArgumentParser(description='Deploy configuration to solace broker.')
parser.add_argument('-b', '--host', help='Broker hostname', required=True)
parser.add_argument('--port', help='Broker ssh port', type=int, default=2222)
parser.add_argument('-u', '--user', help='username of an admin user')
parser.add_argument('-p', '--password', help='password of an admin user')
parser.add_argument('-v', '--vpn', help='target vpn', required=True)
parser.add_argument('--input', help='alternative to stdin this file can be used', nargs='?', type=argparse.FileType('r'), default=sys.stdin)
parser.add_argument(
    '--nuke-vpn', help='Nuke the complete vpn before the deployment', action='store_true')
parser.add_argument('variables', nargs='*', metavar='KEY=VAL', help="Will search for the key in the input and replace it")

args = vars(parser.parse_args())

variables = {}
variables["$VPN$"] = args["vpn"]
for v in args["variables"]:
    parts = v.split("=", 2)
    variables["$" + parts[0] + "$"] = parts[1]

print("Will replacing variables:")
for k in variables.keys():
    print(k + " = " + variables[k])

ssh = paramiko.SSHClient()
ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
ssh.connect(args["host"], port=args["port"],
            username=args["user"], password=args["password"])
shell = ssh.invoke_shell()

while not shell.recv_ready():
    time.sleep(0.5)

# Print banner
out = shell.recv(9999)
print(out.decode("utf-8"))


def sendCmd(shell, cmd):
    if cmd.rstrip() == "":
        return
    shell.send(cmd + "\n")
    print(cmd)

if "nuke-vpn" in args:
    print("Nuking the vpn")
    shell.send('home\n')
    shell.send('enable\n')
    shell.send('configure\n')
    shell.send('message-vpn "' + args["vpn"] + '"\n')
    shell.send('shutdown\n')
    shell.send('exit\n')
    shell.send('no message-vpn "' + args["vpn"] + '"\n')
    shell.send('create message-vpn "' + args["vpn"] + '"\n')
    time.sleep(1)

print("Reading solace cli cmds form stdin/input file")
for line in args["input"]:
    cmd = line.rstrip()
    for search, replace in variables.items():
        cmd = cmd.replace(search, replace)
    sendCmd(shell, cmd)

# Printing the output
# Print banner
shell.send("END_OF_TRANSMISSIONG\n")
while not shell.recv_ready():
    time.sleep(0.5)
out =""
while "END_OF_TRANSMISSIONG" not in out:
    out += shell.recv(9999).decode("utf-8")
print(out)
print("DONE")


