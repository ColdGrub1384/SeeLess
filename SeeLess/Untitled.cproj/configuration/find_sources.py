import os

cwd = os.getcwd()

sources = []
libs = []

# r=root, d=directories, f = files
for r, d, f in os.walk(os.path.dirname(cwd)):
    for file in f:
        if file.endswith(".c") or file.endswith(".cpp"):
            sources.append(os.path.join(r, file))

try:
    # r=root, d=directories, f = files
    for r, d, f in os.walk(os.path.join(os.path.dirname(cwd), "lib")):
        for file in f:
            if file.endswith(".ll") or file.endswith(".bc"):
                libs.append(os.path.join(r, file).replace(" ", "\\ ").replace("'", "\\'").replace('"', '\\"'))
except FileNotFoundError:
    pass

commands = ""

for file in sources:
    commands += "echo Compiling "+os.path.basename(file)+"...\n"
    commands += "clang "
    try:
        if os.environ["VERBOSE"] == "1" or os.environ["VERBOSE"] == 1:
            commands += "-v "
    except KeyError:
        pass
    commands += "--config ../../configuration/configuration.txt {}\n".format(file.replace(" ", "\\ ").replace("'", "\\'").replace('"', '\\"'))

commands += "echo Linking...\n"
commands += "llvm-link *.ll {} -o ../$PRODUCT_NAME\n".format(" ".join(libs))

f = open("objects/.compile.sh", "w")
f.write(commands)
f.close()
