var documenterSearchIndex = {"docs":
[{"location":"api/#API-Documentation","page":"API Documentation","title":"API Documentation","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Docstrings for AutoSysimages.jl interface members can be accessed through Julia's built-in documentation system or in the list below.","category":"page"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"CurrentModule = AutoSysimages","category":"page"},{"location":"api/#Contents","page":"API Documentation","title":"Contents","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Pages = [\"api.md\"]","category":"page"},{"location":"api/#Index","page":"API Documentation","title":"Index","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"Pages = [\"api.md\"]","category":"page"},{"location":"api/#Functions","page":"API Documentation","title":"Functions","text":"","category":"section"},{"location":"api/","page":"API Documentation","title":"API Documentation","text":"start\nlatest_sysimage\njulia_args\nbuild_sysimage\nremove_old_sysimages\npackages_to_include\nset_packages\nstatus\nadd\nremove","category":"page"},{"location":"api/#AutoSysimages.start","page":"API Documentation","title":"AutoSysimages.start","text":"start()\n\nStarts AutoSysimages package. It's usually called by start.jl file; but it can be called manually as well.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.latest_sysimage","page":"API Documentation","title":"AutoSysimages.latest_sysimage","text":"latest_sysimage()\n\nReturn the path to the latest system image produced by AutoSysimages, or nothing if no such image exits.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.julia_args","page":"API Documentation","title":"AutoSysimages.julia_args","text":"julia_args()\n\nGet Julia arguments for running AutoSysimages:\n\n\"-J [sysimage]\" - sets the latest_sysimage(), if it exits,\n\"-L [@__DIR__]/start.jl\" - starts AutoSysimages automatically.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.build_sysimage","page":"API Documentation","title":"AutoSysimages.build_sysimage","text":"build_sysimage(background::Bool = false)\n\nBuild new system image (in background) for the current project including snooped precompiles.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.remove_old_sysimages","page":"API Documentation","title":"AutoSysimages.remove_old_sysimages","text":"remove_old_sysimages()\n\nRemove old sysimages for the current project (active_dir).\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.packages_to_include","page":"API Documentation","title":"AutoSysimages.packages_to_include","text":"packages_to_include()::Set{String}\n\nGet list of packages to be included into sysimage. It is determined based on \"include\" or \"exclude\" options save by Preferences.jl  in LocalPreferences.toml file next to the currently-active project.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.set_packages","page":"API Documentation","title":"AutoSysimages.set_packages","text":"set_packages()\n\nAsk the user to choose which packages to include into the sysimage.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.status","page":"API Documentation","title":"AutoSysimages.status","text":"status()\n\nPrint list of packages to be included into sysimage determined by packages_to_include.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.add","page":"API Documentation","title":"AutoSysimages.add","text":"add(package::String)\n\nSet package to be included into the system image.\n\n\n\n\n\n","category":"function"},{"location":"api/#AutoSysimages.remove","page":"API Documentation","title":"AutoSysimages.remove","text":"remove(package::String)\n\nSet package to be excluded into the system image.\n\n\n\n\n\n","category":"function"},{"location":"#Home","page":"Home","title":"Home","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Automate user-specific system images for Julia","category":"page"},{"location":"","page":"Home","title":"Home","text":"Warning This package uses chained sysimage build that is not yet supported by Julia. You can try that by compiling branch petvana:pv/fastsysimg from source.","category":"page"},{"location":"#Ho-to-install","page":"Home","title":"Ho to install","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"After you install the package to the Julia, you need to include (or symlink) script jusim into the system path. Currently you also need to update Julia's path to where petvana:pv/fastsysimg is compiled.","category":"page"},{"location":"","page":"Home","title":"Home","text":"Then you can run the jusim script providied by the package","category":"page"},{"location":"","page":"Home","title":"Home","text":"#!/usr/bin/env bash\n\n# Runs julia with user-specific system images.\n# This is part of AutoSysimages.jl package\n# https://github.com/petvana/AutoSysimages.jl\n\nJULIA_EXE=[INSERT-YOUR-PATH]/julia\n\njulia_cmd=`$JULIA_EXE -e \"using AutoSysimages; print(AutoSysimages.get_autosysimage_args()); exit(0);\"`\n$JULIA_EXE $julia_cmd \"$@\"\n","category":"page"},{"location":"","page":"Home","title":"Home","text":"Once in a while, it is recomended to run","category":"page"},{"location":"","page":"Home","title":"Home","text":"AutoSysimages.build_system_image()","category":"page"},{"location":"","page":"Home","title":"Home","text":"to rebuild the system image.","category":"page"}]
}
