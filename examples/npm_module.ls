# demonstration of using Updater to modify a node module's version with npm

Updater = require \../lib/updater .Updater

updater = Updater {
	manifest: "http://registry.npmjs.org/machina"
	path: "node_modules/machina"
	# strip package/ from the downloaded tarball
	strip: 1
	# delete the directory before updating installing (TODO)
	destroy: true
}

updater.on \up_to_date (pkg) ->
	console.log "using latest version #{pkg.name}@#{pkg.version}"
	#console.log "updater.manifest", updater._manifest

	updater.exec \export {

		# place the contents inside of 'package/'
		root: 'package'


		#strip: 1

		#   zip file extensions are supported
		#file: "app.zip"

		#   actually, you don't need this line either...
		#   it will, by default put the output file here
		#file: "build/#{pkg.name}-#{pkg.version}.tar.gz"
	}

updater.on \update_available (new_pkg, old_pkg) ->
	if old_pkg
		console.log "update available! #{old_pkg.name}@#{old_pkg.version} #{new_pkg.name}@#{new_pkg.version}!!"
	else
		console.log "new install! #{new_pkg.name}@#{new_pkg.version}!!"
		console.log "to test out the update feature change #{updater.path}/package.json to a lower version"

	updater.exec \update

updater.on \updated (pkg) ->
	console.log "installed #{pkg.name}@#{pkg.version}"
	# not yet fully working :)

updater.on \progress (obj) ->
	console.log "progress", obj

