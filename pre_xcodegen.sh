if ! command -v ~/.mint/bin/mint &> /dev/null; then
  git clone https://github.com/yonaskolb/Mint.git
  cd Mint
  swift run mint install yonaskolb/mint
fi

~/.mint/bin/mint install realm/SwiftLint
