# Widen dotfiles
Because sharing is caring. Inspired by [this blog post](http://www.anishathalye.com/2014/08/03/managing-your-dotfiles/).

### How to install
 - Clone this repo to `~/dotfiles`
 - Branch to namespace your personal settings
   - `git checkout -b dbeg`
 - Push your branch to Github
   - `git push -u dbeg`
 - Add `export PATH=~/.dotfiles/bin:${PATH}` to your shells RC file to get `~/dotfiles/bin` scripts on the path

### How to use
 - Move all dot files to `~/dotfiles` removing the dot prefix
   - `mv .gitconfig dotfiles/gitconfig`
 - Add an alias line for each of your files in `install.conf.yaml`
 - Run `~/dotfiles/install`
 - Use [Github](https://github.com/Widen/dotfiles/branches) to explore other users config
