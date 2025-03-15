all: archive export compress

archive:
	xcodebuild -project MiddleClick.xcodeproj -scheme MiddleClick -configuration Release archive

export:
	xcodebuild -exportArchive \
		-archivePath "$(shell ls -td ~/Library/Developer/Xcode/Archives/*/MiddleClick*.xcarchive | head -1)" \
		-exportPath "$(shell pwd)/build" \
		-exportOptionsPlist ./build-config/ExportOptions.plist

compress:
	cd ./build && \
	rm -f ./MiddleClick.zip && \
	zip -r9 ./MiddleClick.zip ./MiddleClick.app

create-cert:
	security export -k ~/Library/Keychains/login.keychain-db -t identities -f pkcs12 | base64 | pbcopy
