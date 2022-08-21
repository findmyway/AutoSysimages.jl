module AutoSysimages

using REPL
using LLVM_full_jll
using Pkg
using Pidfile
using Dates
using PackageCompiler
using TOML

import Base: active_project

export start, latest_sysimage, julia_args, build_sysimage, remove_old_sysimages
export packages_to_include, set_packages, status, add, remove, active_dir

include("build-PackageCompiler.jl")
include("build-ChainedSysimages.jl")

precompiles_file = ""
is_asysimg = false

snoop_file = nothing
snoop_file_io = nothing

background_task = nothing

function __init__()
    global background_task_lock = ReentrantLock()
    # Set global variables
    projpath = active_project()
    if !isfile(projpath)
        @error "Project file do not exist: $projpath"
        return
    end
    global preferences_path = joinpath(dirname(projpath), "SysimagePreferences.toml")
    # Create short directory name
    adir = active_dir(projpath)
    project_path_file = joinpath(adir, "project-path.txt")
    if !isfile(project_path_file)
        open(project_path_file, "w") do io
            print(io, "$projpath\n")
        end
    end
    global precompiles_file =  joinpath(adir, "snoop-file.jl")
    global image = unsafe_string(Base.JLOptions().image_file)
    # Detect if loaded `image` was produced by AutoSysimages.jl
    global is_asysimg = startswith(basename(image), "asysimg-")
    if is_asysimg
        # Prevent the sysimage to be removed during Julia execution
        global _pidlock = mkpidlock("$image.$(getpid())")
    end
end

"""
    active_dir()

Get diterctory where the sysimage and precompiles are stored for the current project.
The directory is created if it doesn't exist yet.
"""
function active_dir(projpath = active_project())
    hash_name = string(Base._crc32c(projpath), base = 62, pad = 6)
    adir = joinpath(DEPOT_PATH[1], "asysimg", "$VERSION", hash_name)
    !isdir(adir) && mkpath(adir)
    return adir
end

"""
    preferences_path()

Get the file with preferences for the active project (`active_dir()`).
Preferences are stored in `SysimagePreferences.toml` next to the current `Project.toml` file.
"""
preferences_path(projpath = active_project()) = joinpath(dirname(projpath), "SysimagePreferences.toml")

"""
    latest_sysimage()

Return the path to the latest system image produced by AutoSysimages,
or `nothing` if no such image exits.
"""
function latest_sysimage(adir = active_dir())
    !isdir(adir) && return nothing
    files = readdir(adir, join = true)
    sysimages = filter(x -> endswith(x, ".so"), files) |> sort
    return isempty(sysimages) ? nothing : sysimages[end]
end

"""
    julia_args()

Get Julia arguments for running AutoSysimages:
- `"-J [sysimage]"` - sets the `latest_sysimage()`, if it exits,
- `"-L [@__DIR__]/start.jl"` - starts AutoSysimages automatically.
"""
function julia_args()
    if !isfile(active_project())
        @error "Project file do not exist: $projpath"
        return
    end
    image = latest_sysimage()
    startfile = joinpath(@__DIR__, "start.jl")
    return (isnothing(image) ? "" : " -J $image") * " -L $startfile" 
end

"""
    start()

Starts AutoSysimages package. It's usually called by `start.jl` file;
but it can be called manually as well.
"""
function start()
    isfile(active_project()) || return
    _start_snooping()
    txt = "The package AutoSysimages.jl started!"
    if is_asysimg
        txt *= "\n Loaded sysimage:    $image"
    else
        txt *= "\n Loaded sysimage:    Default (You may run AutoSysimages.build_sysimage())"
    end
    txt *= "\n Active directory:   $(active_dir())"
    txt *= "\n Global snoop file:  $precompiles_file"
    txt *= "\n Tmp. snoop file:    $snoop_file"
    @info txt
    if isinteractive()
        _update_prompt()
        if isnothing(_load_preference("include"))
            _set_preference!("include" => [])
            _set_preference!("exclude" => [])
        end
        is_asysimg && VERSION >= v"1.8" && _warn_outdated()
    end
end

"""
    build_sysimage(background::Bool = false)

Build new system image (in `background`) for the current project including snooped precompiles.
"""
function build_sysimage(background::Bool = false)
    is_asysimg = true # Do not ask user to build sysimage again
    if background
        global background_task_lock
        lock(background_task_lock) do
            global background_task
            if isnothing(background_task) || Base.istaskdone(background_task)
                building_task = @task _build_system_image()
                schedule(building_task)
            else
                @warn "System image is already being build!"
            end
        end
    else
        _build_system_image()
    end
end

"""
    remove_old_sysimages()

Remove old sysimages for the current project (`active_dir()`).
"""
function remove_old_sysimages()
    adir = active_dir()
    mkpidlock(joinpath(adir, "rm.lock")) do
        files = readdir(adir, join = true)
        sysimages = filter(x -> endswith(x, ".so"), files)
        latest = latest_sysimage()
        for si in sysimages
            locks = filter(x -> startswith(x, si), files)
            if length(locks) == 1 && si != latest
                @info "AutoSysimages: Removing old sysimage $si"
                rm(si)
            end
        end
    end
end

"""
    set_packages()

Ask the user to choose which packages to include into the sysimage.
"""
function set_packages()
    # TODO - ask user (and print him/her all the options)
    _set_preference!("include" => ["OhMyREPL"])
end

"""
    add(package::String)

Set package to be included into the system image.
"""
function add(package::String)
    include = _load_preference("include")
    exclude = _load_preference("exclude")
    if !isnothing(include) && include isa Vector{String}
        # Add to the `include` list
        package ∉ include && push!(include, package)
        _set_preference!("include" => include)
    else
        if isnothing(exclude) || !(exclude isa Vector{String})
            _set_preference!("include" => [package])
        end
    end
    # Remove from the `exclude` list
    if !isnothing(exclude) && exclude isa Vector{String}
        filter!(!isequal(package), exclude)
        _set_preference!("exclude" => exclude)
    end
end

"""
    remove(package::String)

Set package to be excluded into the system image.
"""
function remove(package::String)
    include = _load_preference("include")
    if !isnothing(include) && include isa Vector{String}
        # Remove from the `include` list
        filter!(!isequal(package), include)
        _set_preference!("include" => include)
    else
        # Add to the `exclude` list
        exclude = _load_preference("exclude")
        if !isnothing(exclude) && exclude isa Vector{String}
            push!(exclude, package)
            _set_preference!("exclude" => exclude)
        else
            exclude = [package]
        end
        _set_preference!("exclude" => exclude)
    end
end

"""
    packages_to_include()::Set{String}

Get list of packages to be included into sysimage.
It is determined based on "include" or "exclude" options save by `Preferences.jl` 
in `LocalPreferences.toml` file next to the currently-active project.
"""
function packages_to_include()
    packages = Set(keys(Pkg.project().dependencies))
    include = _load_preference("include")
    exclude = _load_preference("exclude")
    if !isnothing(include)
        if include isa Vector{String}
            if !isempty(include)
                packages = Set(include)
            end
        else
            if !(include isa Vector) || !isempty(include)
                @warn "Incorrect format of \"include\" in LocalPreferences.toml file."
            end
        end
    end
    if !isnothing(exclude)
        if exclude isa Vector{String}
            for e in exclude
                delete!(packages, e)
            end
        else
            if !(exclude isa Vector) || !isempty(exclude)
                @warn "Incorrect format of \"exclude\" in LocalPreferences.toml file."
            end
        end
    end
    return packages
end

"""
    status()

Print list of packages to be included into sysimage determined by `packages_to_include`.
"""
function status()
    if Base.have_color
        printstyled("    Project ", color = :magenta)
    else
        print("    Project ")
    end
    println("`$(active_project())`")
    if Base.have_color
        printstyled("   Settings ", color = :magenta)
    else
        print("   Settings ")
    end
    println("`$preferences_path`")

    println("Packages to be included into sysimage:")
    versions = Dict{String, Tuple{Any, Any}}()
    for d in Pkg.dependencies()
        uuid = d.first
        version = d.second.version
        name = d.second.name
        versions[name] = (uuid, version)
    end
    packages = packages_to_include()
    for name in packages
        if !isnothing(get(versions, name, nothing))
            uuid, version = versions[name]
            if Base.have_color
                printstyled("  [", string(uuid)[1:8], "] "; color = :light_black)
            else
                print("  [", string(uuid)[1:8], "] ")
            end
            println("$name v$version")
        else
            @warn "Package $name is not in the project and cannot be included in sysimg."
        end
    end
end

function _warn_outdated()
    if VERSION < v"1.8"
        @warn "Julia v1.8+ is needed to check package versions."
        return
    end
    versions = Dict{Base.UUID, VersionNumber}()
    outdated = Tuple{String, VersionNumber, VersionNumber}[]
    for d in Pkg.dependencies()
        uuid = d.first
        version = d.second.version
        isnothing(version) || (versions[uuid] = version)
    end
    for l in Base.loaded_modules
        uuid = l.first.uuid
        version = pkgversion(l.second)
        dep_version = get(versions, uuid, version)
        if dep_version != version && !isnothing(version)
            push!(outdated, (l.first.name, version, dep_version))
        end
    end
    if !isempty(outdated)
        txt = "Some packages are outdated. Consider calling build_sysimage()."
        for out in outdated
            txt *= "\n - $(out[1]): $(out[2]) -> $(out[3])"
        end
        @warn txt
    end
end

function _start_snooping()
    global snoop_file_io
    if snoop_file_io === nothing
        global snoop_file = "$(tempname())-snoop.jl"
        mkpath(dirname(snoop_file))
        global snoop_file_io = open(snoop_file, "w")
        ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), snoop_file_io.handle)
        atexit(_stop_snooping)
    else
        @warn("Snooping is already running -> $(snoop_file)")
    end
end

function _stop_snooping()
    global snoop_file_io
    if isnothing(snoop_file_io)
        @warn("No active snooping file")
        return 
    end
    ccall(:jl_dump_compiles, Cvoid, (Ptr{Cvoid},), C_NULL)
    close(snoop_file_io)
    snoop_file_io = nothing
    _save_statements()
    isfile(snoop_file) && rm(snoop_file)
    if !is_asysimg
        @warn "There is no sysimage for this project. Do you want to build one?"
        if REPL.TerminalMenus.request(REPL.TerminalMenus.RadioMenu(["Yes", "No"])) == 1
            build_sysimage()
        end
    end
end

function _flush_statements()
    !isnothing(snoop_file_io) && flush(snoop_file_io)
end

function _save_statements()
    _flush_statements()
    lines = readlines(snoop_file)
    act_precompiles = String[]
    for line in lines
        sp = split(line, "\t")
        length(sp) == 2 && push!(act_precompiles, sp[2][2:end-1])
    end

    global precompiles_file
    @info("AutoSysimages: Copy snooped statements to: $(precompiles_file)")
    mkpidlock("$precompiles_file.lock") do
        oldprec = isfile(precompiles_file) ? readlines(precompiles_file) : String[]
        old = Set{String}(oldprec)
        open(precompiles_file, "a") do file
            for precompile in act_precompiles
                if precompile ∉ old
                    push!(old, precompile)
                    write(file, "$precompile\n")   
                end     
            end
        end
    end
end

# TODO - make it compatible with OhMyREPL
function _update_prompt(isbuilding::Bool = false)
    function _update_prompt(repl::AbstractREPL)
        mode = repl.interface.modes[1]
        mode.prompt = "asysimg> "
        if Base.have_color
            mode.prompt_prefix = Base.text_colors[isbuilding ? :red : :magenta]
        end
    end
    repl = nothing
    if isdefined(Base, :active_repl) && isdefined(Base.active_repl, :interface)
        repl = Base.active_repl
        _update_prompt(repl)
    else
        atreplinit() do repl
            if !isdefined(repl, :interface)
                repl.interface = REPL.setup_interface(repl)
            end
            _update_prompt(repl)
        end
    end
end

function _build_system_image()
    t = Dates.now()
    t_start = time()
    sysimg_file = joinpath(string(active_dir()), "asysimg-$t.so")
    chained = false
    try 
        # Enable chained building of system image
        # See https://github.com/JuliaLang/julia/pull/46045
        @ccall jl_precompiles_for_sysimage(1::Cuchar)::Cvoid;
        chained = true
    catch 
    end
    if chained
        _build_system_image_chained(sysimg_file)
    else
        _build_system_image_package_compiler(sysimg_file)
    end
    @info "AutoSysimages: Builded in $(time() - t_start) s"
end

function _set_preference!(pair::Pair{String, T}) where T
    if isfile(preferences_path)
        project = Base.parsed_toml(preferences_path)
    else
        project = Dict{String,Any}()
    end
    if !haskey(project, "AutoSysimages")
        project["AutoSysimages"] = Dict{String,Any}()
    end
    project["AutoSysimages"][pair.first] = pair.second
    # Sort such that `include` and `exclude` are first
    function by_fce(x)
        x == "include" && return "1"
        x == "exclude" && return "2"
        return "3" * x
    end
    open(preferences_path, "w") do io
        TOML.print(io, project; sorted=true, by=by_fce)
    end
end

function _load_preference(key::String)
    !isfile(preferences_path) && return nothing
    project = Base.parsed_toml(preferences_path)
    if haskey(project, "AutoSysimages")
        dict = project["AutoSysimages"]  
        if dict isa Dict
            return get(dict, key, nothing)
        end
    end
    return nothing
end

end # module
