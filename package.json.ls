# Upgrader!

name: 'upgrader'
version: '0.1.0'
description: 'updating made easy'
keywords: [
	'update' 'upgrade'
]
homepage: 'https://github.com/duralog/Upgrader'
author: 'Kenneth Bentley <funisher@gmail.com>'
contributors: [
	'Kenneth Bentley <funisher@gmail.com>'
]
maintainers: [
	'Kenneth Bentley <funisher@gmail.com>'
]
engines:
	node: '>0.8.3'
repository:
	type: 'git'
	url: 'https://github.com/duralog/Upgrader.git'
bugs:
	url: 'https://github.com/duralog/Upgrader/issues'
main: './lib/updater.js'
dependencies:
	semver: \x
	request: \x
	fstream: \x
	'fstream-ignore': \x
	tar: \x
	temp: \x
	rimraf: \x
	debug: \x
	lodash: \x
	archivista: \x
	machineshop: \x
	#mental: \x
directories:
	src: 'src'
	lib: 'lib'
	#doc: 'doc'
	example: 'examples'
sencillo:
	universe: \facilmente
	creator:
		name: 'duralog'
		email: 'funisher@gmail.com'
#updater:
#	manifest: ...
#	repository:
#		type: \git
#		url: 'git://github.com/duralog/Upgrader.git'
