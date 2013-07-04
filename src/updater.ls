
spawn = require \child_process .spawn
Url = require \url
Path = require \path
Fs = require \fs
Zlib = require \zlib
Debug = require \debug

Semver = require \semver
Request = require \request
Fstream = require \fstream
Ignore = require \fstream-ignore
Tar = require \tar
Temp = require \temp
Rimraf = require \rimraf

Archivista = require \archivista
MachineShop = require \machineshop
ToolShed = MachineShop.ToolShed
Fsm = MachineShop.Fsm
#Fsm = require \Mental .Fsm

Updaters = {}
export Updater = (opts, update_done_cb) ->
	# opts.uri (currently, only http is supported)
	# IMPROVEMENT: add git support - repo/commit_sha
	# maybe add a self-updater:
	#  "https://raw.github.com/duralog/Updater/master/.updater.manifest.json"
	unless opts.manifest => throw new Error "you must provide a manifest uri"
	unless opts.path => throw new Error "you must provide a destination path"

	real_path = Path.resolve opts.path
	if updater = Updaters[real_path]
		return updater
	# INCOMPLETE: should be dynamic (and overridable by --force)
	unless opts.update_interval => opts.update_interval = 1 #(24*60*60*1000)

	MANIFEST_URI = Url.parse opts.manifest
	UPDATER_CACHE = Path.join process.env.HOME, ".Updater"

	console.log Path.join UPDATER_CACHE, MANIFEST_URI.host || '', MANIFEST_URI.path.replace(/[\/\?]/g, '-'), 'manifest.json'
	manifest_path = Path.join UPDATER_CACHE, MANIFEST_URI.host || '', MANIFEST_URI.path.replace(/[\/\?]/g, '-'), 'manifest.json'
	#pkg_json_path = Path.join process.cwd!, 'package.json'
	pkg_json_path = Path.join opts.path, 'package.json'
	console.log "pkg_js", pkg_json_path

	debug = Debug 'Updater'
	CORES = 2
	OS = switch process.platform
	| \darwin => \osx
	| \linux => \linux
	| \android => \android
	| otherwise => throw new Error "unsupported platform!"
	ARCH = switch process.arch
	| \x64 => \x86_64
	| otherwise => \webkit
	/*	console.log "lala"
		console.log window.process.versions.'node-webkit' #, process.versions
		if window.process?versions?'node-webkit'
			'webkit-'+process.versions.'node-webkit'
		else throw new Error "only 64 bits supported for now..."
	*/
	#switch OS
	#| \osx =>
	#	CORES = $p "sysctl hw.ncpu" .pipe "awk '{print $2}'" .data (err, stdout, stderr) ->
	#		if stdout then CORES := Math.round (''+stdout) * 1
	#| \linux =>
	#	CORES = $p "grep -c ^processor /proc/cpuinfo" .data (err, stdout, stderr) ->
	#		if stdout then CORES := Math.round (''+stdout) * 1

	Updaters[real_path] =\
	updater = new Fsm "Updater" {
		initialize: ->
			console.log "initializing Updater"

		states:
			uninitialized:
				_onEnter: ->
					unless opts.version => opts.version = 'x'
					ToolShed.mkdir opts.path, (err, dir) ->
						if err
							updater.transition \error
						else if typeof dir is \string
							#updater.transition \get_manifest
							updater.transition \get_manifest
						else
							Fs.stat manifest_path, (err, st) ->
								if err
									ToolShed.mkdir Path.dirname(manifest_path), (res) ->
										#updater.transition \get_manifest
										updater.transition \pkg_json
								else
									updater._manifest_st = st
									updater.transition \pkg_json
			pkg_json:
				_onEnter: ->
					Fs.readFile pkg_json_path, \utf-8, (err, data) ->
						unless err
							try
								updater._package_json = json = JSON.parse data
								updater.name = json.name
								updater.version = json.version
							catch e
								# how do I recover from this???
								err = e
						if err and err.code isnt \ENOENT => throw err
						updater.transition \get_manifest

			get_manifest:
				_onEnter: ->
					if not updater._manifest_st or (Date.now! - updater._manifest_st.mtime) > opts.update_interval
						(err, dir) <- ToolShed.mkdir Path.dirname manifest_path
						lo = Fs.createWriteStream manifest_path
						lo.on \error (err) ->
							if err.code is \ENOENT
								updater.transition \ready
							else
								updater.transition \error
						process_res = (err, res) ->
							var update
							if err => return updater.transition \error
							try
								updater._manifest = json = JSON.parse res.request.response.body
								updater.emit \manifest, json
								switch opts.version
								| \latest \x \* =>
									version = json.'dist-tags'.latest
								| otherwise =>
									version = opts.version
								unless json = json.versions[version]
									debug "version #{name}@#{version} could not be found."
									_.each json.versions, (m, vv) ->
										if Semver.satisfies(vv, version) and Semver.gt(vv, version)
											version := vv
											update := m
									unless update
										update := json.versions[json.'dist-tags'.latest]

								debug "resolved to #{json.version}"

								updater.transition \ready

								if j = updater._package_json
									#if j.name isnt manifest.name
									if not Semver.satisfies(j.version, version) and Semver.gt version, j.version
										debug "not satisifies ... update_available %s -> %s", j.version, version
										process.nextTick ->
											updater.emit \update_available json, j
									else
										process.nextTick ->
											updater.emit \up_to_date, updater._package_json
								else
									process.nextTick ->
										updater.emit \update_available json
							catch e
								console.log "exception!", e.stack
								updater.transition \error
						lo.on \error ->
							console.error "ERR", &
						lo.on \open ->
							switch MANIFEST_URI.protocol
							| \file: =>
								# kinda a lame hack, I know... I'll fix it :)
								Fs.readFile MANIFEST_URI.path, \utf-8, process_res
								dl = Fs.createReadStream MANIFEST_URI.path, process_res
								dl.pipe lo
								dl.on \error (err) ->
									if err => return updater.transition if err.code is \ENOENT => \ready else \error
							| \http: \https: =>
								dl = Request.get MANIFEST_URI.href, process_res
								dl.pipe lo
					else
						updater.emit \up_to_date, updater._package_json
						updater.transition \ready

			updating:
				_onEnter: ->
					manifest = updater._update
					var url
					if manifest.binaries
						for bin in manifest.binaries
							if bin.type is \gzip
								url = bin.url.replace /{{OS}}/g, OS
									.replace /{{ARCH}}/g, ARCH
									.replace /{{VERSION}}/g, UNIVERSE.version
					unless url => url = manifest.dist.tarball
					#Temp.mkdir 'updater', (err, tmpdir) ->
					#	process.on \exit ->
					#		Rimraf tmpdir, ->
					#			console.log "cleaned up"
					tmpdir = Path.join require('os').tmpdir!, 'updater'
					#if true
					ToolShed.mkdir tmpdir, (res) ->
						task = updater.task 'downloading update'
						if opts.destroy
							task.choke (done) ->
								Rimraf opts.path, done
						local = Path.join tmpdir, Path.basename url
						task.choke (done) ->
							tar = Archivista.dl_and_untar {
								url: url
								file: local
								path: opts.path
								task: task
								strip: opts.strip
								sha1: manifest.dist.shasum
							}, (err, res) ->
								#Fs.unlink local
								done err, res
							tar.on \progress, (data) ->
								debug ".. (#{data.bytes}/#{data.bytesTotal})"
								updater.emit \progress, data
						task.end (err, res) ->
							#updater.transition \ready
							#process.nextTick ->
							Fs.readFile pkg_json_path, \utf-8, (err, data) ->
								try
									updater._package_json = JSON.parse data
								catch e
									err = e
								if err => return updater.transition \error
								updater.transition \uninitialized
								updater.emit \updated, updater._package_json
							#Temp.cleanup!


			ready:
				_onEnter: ->
					@emit \ready

				update: (version) ->
					# TODO: select a distint version you want to upgrade to
					unless version
						version = updater._manifest.'dist-tags'.latest
					unless manifest = updater._manifest
						@transition \get_manifest
					#else if not updater._package_json
					#	@transition \pkg_json
					else if updater._package_json and Semver.eq version, updater._package_json.version
						@emit \up_to_date, updater._package_json
					else if update = manifest.versions[version]
						updater._update = update
						@transition \updating

				export: (options, cb) ->
					# do a tar of the directory
					unless options.path => options.path = opts.path+''
					#unless options.file => options.file = Path.join(\build, Path.basename(options.path)) + '.tar.gz'
					unless options.file => options.file = Path.join \build, "#{updater._package_json.name}-#{updater._package_json.version}.tar.gz"
					(dir) <- ToolShed.mkdir Path.dirname options.file
					out = Fs.createWriteStream file = options.file
					out.on \open ->
						unless options.type
							options.type = switch ext = file.substr 1+file.lastIndexOf '.'
							| 'tgz' 'gz' => \gzip
							| 'tbz' 'bz' => \bzip
							| 'txz' 'xz' => \xz
							| 'zip' 'nw' => \zip # nw support for node-webkit. go check it out!

						# IMPROVEMENT: read the contents of .npmignore and use it for ignoreRules
						done_files = 0
						total_files = 0
						total_bytes = 0
						progress = (walkietalkie) ->
							walkietalkie.on \entries (entries) ->
								total_files += entries.length
							walkietalkie.on \entry (res) ->
								done_files++
								if res.type is \File
									total_bytes += res.size
									debug "(#{done_files}/#{total_files}) #{total_bytes}" # res
								else if res.type is \Directory
									if entries = res.entries
										total_files += entries.length
									else progress res
						progress fs = new Ignore path: options.path, ignoreFiles: ['.git' '.npmignore' 'README.md']
						if options.type is \zip
							console.error "XXX: ignored files are not respected! add this to Archiver"
							zip = new Archivista.Zip {file: file, root: options.root, strip: 1}
							zip.add options.path, -> zip.done!
						else
							fs.pipe tar = Tar.Pack noProprietary: true


						fs.on \error (err) ->
							console.log "ERROR", err.stack
						fs.on \data ->
							console.log "data"

						# TODO: pipe through these execs
						# TODO: move this functionality over to Archivista
						# xz -c -z <-- compress
						# xz -c -d <-- decompress
						# bzip2 -c -d <-- decompress
						switch options.type
						| \xz \lzma => tar.pipe require('xz-pipe').z! .pipe out
						| \gzip =>
							tar.pipe Zlib.createGzip {level: 9 memLevel: 9} .pipe out
						| \zip =>
							#tar.pipe Zlib.createDeflate! .pipe out
						| \tar =>	tar.pipe out
						| otherwise => throw new Error "unknown compression type"
					out.on \close ->
						debug "exported: %s", file
						updater.emit \exported, options

				release: (version) ->
					unless Semver.valid version
						throw new Error "invalid version!"
					console.log "doing release", version, updater._package_json
					unless updater._package_json
						console.log "first release, huh?"
						console.log "you gatta have a package.json to make a release... amongst other things"
						return updater.transition \ready

					manifest = updater._manifest || {
						_id: updater._package_json.name
						#_rev
						name: updater._package_json.name
						description: updater._package_json.description
						'dist-tags': latest: version
						versions: []
							#'1.0.1': {_id: 'pkg@1.0.1' _npmUser: {}}
						author: updater._package_json.author
						maintainers: updater._package_json.maintainers
						time: {}
							#'1.0.1': new Date!toISOString!
					}

					if version is updater._package_json.version || manifest.versions[version]
						console.log "need to add version overwriting on --force"
						throw new Error "this version already exists"

					@exec \export, {
						file: Path.join \build, \releases, version, "package.tgz"
					}
					@once \exported, (res) ->
						# versions.dist
						manifest.name = updater._package_json.name
						manifest.version = updater._package_json.version
						manifest.time[version] = new Date!toISOString!
						update = {} <<< updater._package_json
						update.dist = {
							shasum: res.shasum
							tarball: res.file
						}
						update._id = manifest.name+'@'+manifest.version
						manifest.versions[version] = update

	}
	if typeof update_done_cb is \function
		updater.once \ready ->
			update_done_cb null, updater
	return updater

