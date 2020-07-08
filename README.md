# jit
"Jack's Idiotic Terminal-client"



## Installation

To quickly try `jit` out, download `jit.sh` and place it in your root directory. Add `alias jit='sh ~./jit.sh'` to your `~/.bashrc` file. 

For a more proper install, download `jit.sh` and run `mv jit.sh /usr/local/bin/jit`, followed by `chmod +x /usr/local/bin/jit`.

## Use

Type `jit commit` to launch the commit-interface. Select the files you want to stage/unstage, navigating with the arrow keys and using <kbd>Enter</kbd> to toggle. Select "`COMMIT`" and type the commit message to finish; entering an empty message will **cancel the commit**. Type `jit push` to push the changes.

Type `jit help` for a list of availible commands.
