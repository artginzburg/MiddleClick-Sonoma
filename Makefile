all: archive export

archive:
	xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Release archive

export:
	xcodebuild -exportArchive \
		-archivePath "$(shell ls -td ~/Library/Developer/Xcode/Archives/*/MiddleClick*.xcarchive | head -1)" \
		-exportPath "$(shell pwd)/build" \
		-exportOptionsPlist ./build-config/ExportOptions.plist
