import paramiko
import argparse
import sys
import time
import re

parser = argparse.ArgumentParser(
    description='Deploy configuration to solace broker.')
parser.add_argument('-b', '--host', help='Broker hostname', required=True)
parser.add_argument('--port', help='Broker ssh port', type=int, default=2222)
parser.add_argument('-u', '--user', help='username of an admin user')
parser.add_argument('-p', '--password', help='password of an admin user')
parser.add_argument('-v', '--vpn', help='target vpn', required=True)
parser.add_argument('--input', help='alternative to stdin this file can be used',
                    nargs='?', type=argparse.FileType('r'), default=sys.stdin)
parser.add_argument(
    '--nuke-vpn', help='Nuke the complete vpn before the deployment', action='store_true')
parser.add_argument('variables', nargs='*', metavar='KEY=VAL',
                    help="Will search for the key in the input and replace it")

args = vars(parser.parse_args())

variables = {}
variables["$VPN$"] = args["vpn"]
for v in args["variables"]:
    parts = v.split("=", 2)
    variables["$" + parts[0] + "$"] = parts[1]

print("Will replacing variables:")
for k in variables.keys():
    print(k + " = " + variables[k])


class SolaceShellApplier:
    def __init__(self, args):
        ssh = paramiko.SSHClient()

        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        ssh.connect(args["host"], port=args["port"],
                    username=args["user"], password=args["password"])
        shell = ssh.invoke_shell()

        shell.setblocking(1)
        shell.settimeout(45)

        self.__shell = shell

        self.__new_cmd_line_re = re.compile(re.escape(self.__readBannerAndGetHostname()) + "(\([^\)]+\))?[\>\#]\s*$")
        shell.settimeout(15)

    def __readBannerAndGetHostname(self):
        hostname_re = r"([a-zA-Z0-9\-\.]+)\>\s*$"

        banner = ""
        while True:
            banner += self.__shell.recv(9999).decode("utf-8") + "\n"
            matches = re.search(hostname_re, banner)
            if matches:
                print(banner)
                return matches.group(1)


    def apply(self, cmd):
        if cmd.rstrip() == "":
            return ""
        self.__shell.send(cmd + "\n")

        # Read response
        out = ""
        i = 0
        while True:
            out += self.__shell.recv(9999).decode("utf-8")
            i += 1
            if re.search(self.__new_cmd_line_re, out):
                return out.strip()
            if "Do you want to continue" in out:
                self.__shell.send("y\n")
            if i > 2:
                time.sleep(0.2)
            if i > 30:
                print("## No more response from server. i die. ##")
                sys.exit(1)


ssa = SolaceShellApplier(args)

# if "nuke-vpn" in args:
#     print("Nuking the vpn")
#     shell.send('home\n')
#     shell.send('enable\n')
#     shell.send('configure\n')
#     shell.send('message-vpn "' + args["vpn"] + '"\n')
#     shell.send('shutdown\n')
#     shell.send('exit\n')
#     shell.send('no message-vpn "' + args["vpn"] + '"\n')
#     shell.send('create message-vpn "' + args["vpn"] + '"\n')
#     time.sleep(1)

def sendLine(ssa, line):
    cmd = line.strip()
    for search, replace in variables.items():
        cmd = cmd.replace(search, replace)

    out = ssa.apply(cmd)

    if "must be shutdown prior to being deleted" in out:
        # Handle delete issues. That can not be set via cli without knoing the current state.
        # < no queue xyz
        # > The Queue must be shutdown prior to being deleted
        # > queue xyz
        # > shutdown
        # > exit
        # > no queue xyz
        # ;-)
        out += " " + ssa.apply(cmd[3:])
        out += " " + ssa.apply("shutdown")
        out += " " + ssa.apply("exit")
        out += " " + ssa.apply(cmd)

    return out

print("Reading solace cli cmds form stdin/input file")
for line in args["input"]:
    out = sendLine(ssa, line)
    print(out, end=' ')
print("DONE")
