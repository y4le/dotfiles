# turn hidden files on/off in OSX Finder
function hiddenOn() {
  defaults write com.apple.Finder AppleShowAllFiles YES && killall Finder
}
function hiddenOff() {
  defaults write com.apple.Finder AppleShowAllFiles NO && killall Finder
}
