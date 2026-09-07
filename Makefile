.PHONY: pre-release-bump
pre-release-bump:
	npm version prerelease --preid rc
	git push origin HEAD --tags

.PHONY: publish-pre-release
publish-pre-release:
	npm publish --tag next

.PHONY: check
check:
	bun run check
