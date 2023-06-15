
# look at file changelog.txt, take all bullet points under the top header.

def get_changelog_notes():
    with open('changelog.txt', 'r') as f:
        lines = f.readlines()
        lines = lines[1:]
        latest_changes = ""
        for line in lines:
            line = line.strip()
            if line == "":
                continue
            if not line.startswith('-'):
                line = "- " + line
            latest_changes += line + "\n"
        return latest_changes

if __name__ == '__main__':
    latest_changes = get_changelog_notes()
    print(latest_changes)
    # write value to a file
    with open('latest_changes', 'w') as f:
        f.write(latest_changes)
