if ! command -v mint &> /dev/null; then
  git clone https://github.com/yonaskolb/Mint.git
  cd Mint
  swift run mint install yonaskolb/mint
fi

mint install realm/SwiftLint
