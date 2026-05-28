#ln -s ~/dots/alacritty ~/.config/alacritty

DOTLINKS=(
  'alacritty'
  'fastfetch'
  'aseprite'
  'backgrounds'
  'fuzzel'
  'kew'
  'mako'
  'niri'
  'PixiEditor'
  'quickshell'
  'swaylock'
  'colors.txt'
  'nvim'
  'ghostty'
)

for link in "${DOTLINKS[@]}"
do
  echo "Testing for presence of symlink" $link
  test -L ~/.config/$link &&
    echo "symbolic link already doing nothing" ||
    ln -s ~/dots/$link ~/.config/$link
done
