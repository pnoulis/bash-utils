#!/usr/bin/env bash

set -o errexit

EXECDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)

# Options
PKGDIR=.
ENVDIR=.
MODE=production
BUILD=
HOST=
TARGET=
CLIENV=
declare -gA SWITCH_PREFIXES=()

# Loaded environment
declare -gA ENV=()

usage() {
    cat <<EOF
${0} was created with the intented goals of:

     1. Decouple the loading of the environment from any
     one specific build system, library or language thus
     decreasing external dependencies.

     2. Separate the configuration stage from the build stage
     following the 12 factor app guidelines: https://12factor.net/

     2. Assist the developer by removing at least one headache.
     The headache being having to use search for a new way
     to load the environment every time a new tool is used
     because it is not compatible with the old.

     4. Have the envars available at an early stage in the build
     procedure so that multiple tools or runtimes may utilize them.

     5. Gather all of the environment in its possible permutations
     dev,prod,staging,... into a single file. The dependents then
     only need to load that file and it makes it easier for the
     developer to inspect it.

[BEHAVIOR]:
  ${0} needs to be provided with its parameters otherwise it exits
  with an error.

  Dotenv categorizes the loading of the environment in three stages.
  1. loading of static envars files
  2. loading of local envars files
  3. loading of process environment
  4. loading of cli environment
  5. expansion
  6. prefix switch
  7. writting out the loaded environment

  --- 1. Loading of the static environment
  Static envars files are those that are usually commited in a repository.
  ${0} looks for these in the --envdir directory and loads them according
  to the --mode specified.

  For example:
  If the --mode=(dev || development)

  ${0} will load:
  env
  env.[dev|development]

  If an envar has been defined twice in both of these files that the moded file
  takes priority.

  * Notice how the files under --envdir are not hidden. Why should they? They are
  made globally available through the use of public cloud repositories.

  ${0} defines the following modes:
  1. dev | development
  2. stag | staging
  3. prod | production

  More can easily be added.

  --- 2. Loading of the local environment
  Local envars are those that are not commited in a repository. They are
  usefull for keeping sensitive information and overriding the pre-configured
  environments.
  ${0} Looks for these in the --pkgdir which corresponds to the root directory
  of your project.

  They are loaded in the same order as static envar files according to the --mode

  .env
  .env[dev|development]

  * Notice how these files are expected to be dotfiles (hidden). Not so much to
  keep them safe but rather to declutter the view.

  --- 3. Loading of the process enviroment
  Environment variables that have already been loaded at this stage are replaced
  by those inherited from the parent process environment. Therefore if an envar
  is not already part of the ENV map it shall not be copied.

  --- 4. Loading of the cli environment
  Specifically all envars declared through the parameter -e are loaded.
  The MODE and TARGET variables are also made part of the ENV at this point in time.

  --- 5. Expansion
  It is sometimes usefull to be able to construct an envar by referering other
  envars which may have been already defined or will be at some later loading stage.

  Example:
  SOME_ENV=basic
  SOME_ENV_EXPANDED=${SOME_ENV}_expansion
  SOME_ENV_DEFAULT=${MISSING_ENV:-yolo}_expansion

  * Notice how the expansion supports defaults in the case of a missing environment

  --- 6. Prefix switch
  Switches prefixes or adds a prefix.

  --switch-prefixes='one:two,three:four'
  --switch-prefixes='one:two'

  --- 7. Writting out the loaded environment.
  ${0} First truncates and then writes the loaded enviroment at the <project_root>/.env

  The project root is specified through the paramater --pkgdir.

[USAGE]: ${0} [OPTION]
    -m, --mode - config mode
             If --mode is not provided the script looks for a value
             through the process envar MODE
    --build - build machine
             --build= -> the machine currently building the program
    --host - host machine
             --host= -> the machine that shall host the binary
    --target - target machine
             --target= -> the machine that the binary has been compiled for.
    -e, --environment='key=value;'
             Each key value pair denotes an environment variable.
             Each pair is separated by a semicolon ';'
    --envdir - The root directory of the environment variable files
             or the process envar ENVDIR
    --pkgdir - The root directory of the package / application.
             or the process envar PKGDIR
    --switch-prefixes - a key value pair conforming to the syntax:
              <key>:<value>,<key>:<value>,...
              keys are used to filter a subset of the available
              environment and values are used to replace the key
              in the output file.
              see [EXAMPLES]
    -h, --help - Show this message

[EXAMPLES]:

EOF
}

main() {
    parse_args "$@"
    set -- "${POSARGS[@]}"

    # If PKGDIR or ENVDIR do not pass tests exit
    if [[ -z "${PKGDIR:-}" ]]; then
        die "Missing \$PKGDIR"
    fi
    PKGDIR=$(realpath "${PKGDIR}")
    cd -- "${PKGDIR}" || die "Could not cd into PKGDIR:${PKGDIR}"
    ENVDIR=${ENVDIR:-${PKGDIR}/config/env}
    if [[ -z "${ENVDIR:-}" ]]; then
        die "Missing \$ENVDIR"
    fi
    ENVDIR=$(realpath "${ENVDIR}")
    cd -- "${ENVDIR}" || die "Could not cd into ENVDIR:${ENVDIR}"

    load_static_env
    load_local_env
    load_proc_env
    load_clienv
    expand_envars
    switch_prefixes
    write_env
}

load_clienv() {
    while IFS=';' read -r -d';' key; do
        ENV["${key%%=*}"]="${key##*=}"
    done <<<"${CLIENV}"

    if [[ -n "${MODE:-}" ]]; then
        ENV['MODE']=${MODE}
    fi

    if [[ -n "${BUILD:-}" ]]; then
        ENV['BUILD']=${BUILD}
    fi

    if [[ -n "${HOST:-}" ]]; then
        ENV['HOST']=${HOST}
    fi

    if [[ -n "${TARGET:-}" ]]; then
        ENV['TARGET']=${TARGET}
    fi

}

ensure_newline() {
    find . -mindepth 1 -type f -iregex '.*env.*' | xargs -I {} sed -i -e '$a\' {}
}

switch_prefixes() {
    if (( "${#SWITCH_PREFIXES[@]}" == 0 )); then
        return
    fi
    local -A filtered=()
    local newkey
    local prefixed
    for envar in "${!ENV[@]}"; do
        prefixed=0
        for filter in "${!SWITCH_PREFIXES[@]}"; do
            newkey=
            if [[ "$filter" == 'add' ]]; then
                newkey="${SWITCH_PREFIXES[$filter]}${envar}"
                filtered[$newkey]=${ENV[$envar]}
                envar=${newkey}
                prefixed=1
                break
            elif [[ "${envar:-}" =~ "$filter" ]]; then
                newkey="${envar/$filter/${SWITCH_PREFIXES[$filter]}}"
                filtered[$newkey]=${ENV[$envar]}
                envar=${newkey}
                prefixed=1
                break
            fi
        done
        if (( !$prefixed )); then
            filtered[$envar]=${ENV[$envar]}
        fi
    done
    unset ENV || die "failed to unset ENV in switch_prefixes"
    declare -gA ENV
    for i in "${!filtered[@]}"; do
        ENV[$i]=${filtered[$i]}
    done
}

expand_envars() {
    set -o allexport
    for i in "${!ENV[@]}"; do
        export ${i}=${ENV[$i]}
    done

    for i in "${!ENV[@]}"; do
        declare "${i}"=$(eval echo "${ENV[$i]}")
        ENV[$i]=$(eval echo "${ENV[$i]}")
    done
}

load_proc_env() {
    for i in "${!ENV[@]}"; do
        if [[ -n "${!i}" ]]; then
            ENV[$i]=${!i}
        else
            ENV[$i]=${ENV[$i]}
        fi
    done
}

write_env() {
    cd $PKGDIR
    cat /dev/null > .env
    for i in "${!ENV[@]}"; do
        echo "${ENV_PREFIX:-}${i}=${ENV[$i]}" >> .env
    done
}

load_local_env() {
    cd $PKGDIR
    ensure_newline
    if [[ -f "./.env.local" ]]; then
        while IFS== read -r key value; do
            ENV[$key]=$value
        done < "./.env.local"
    fi
    case "${MODE:-}" in
        dev | development)
            if [[ -f './.env.development.local' ]]; then
                while IFS== read -r key value; do
                    ENV["$key"]="$value"
                done < "./.env.development.local"
            elif [[ -f './.env.dev.local' ]]; then
                while IFS== read -r key value; do
                    ENV["$key"]="$value"
                done < "./.env.dev.local"
            fi
            ;;
        stag | staging)
            if [[ -f './.env.staging.local' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./.env.staging.local"
            elif [[ -f './.env.stag.local' ]]; then
                while IFS== read -r key value; do
                    ENV["$key"]="$value"
                done < "./.env.stag.local"
            fi
            ;;
        prod | production)
            if [[ -f './.env.production.local' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./.env.production.local"
            elif [[ -f './.env.prod.local' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./.env.prod.local"
            fi
            ;;
        *)
            die "Unrecognized mode:${MODE:-}"
            ;;
    esac
}

load_static_env() {
    cd $ENVDIR
    ensure_newline
    while IFS== read -r key value; do
        ENV[$key]=$value
    done < "./env"
    case "${MODE:-}" in
        dev | development)
            if [[ -f './env.development' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.development"
            elif [[ -f "./env.dev" ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.dev"
            fi
            ;;
        stag | staging)
            if [[ -f './env.staging' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.staging"
            elif [[ -f "./env.stag" ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.stag"
            fi
            ;;
        prod | production)
            if [[ -f './env.production' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.production"
            elif [[ -f "./env.prod" ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.prod"
            fi
            ;;
        *)
            die "Unrecognized mode:${MODE:-}"
            ;;
    esac
}

parse_args() {
    declare -ga POSARGS=()
    while (($# > 0)); do
        case "${1:-}" in
            -m | --mode*)
                MODE=$(OPTIONAL=0 parse_param "$@") || shift $?
                ;;
            --build*)
                BUILD=$(parse_param "$@") || shift $?
                ;;
            --host*)
                HOST=$(parse_param "$@") || shift $?
                ;;
            --target*)
                TARGET=$(parse_param "$@") || shift $?
                ;;
            -e | --environment*)
                CLIENV=$(parse_param "$@") || shift $?
                ;;
            --pkgdir*)
                PKGDIR=$(parse_param "$@") || shift $?
                ;;
            --envdir*)
                ENVDIR=$(parse_param "$@") || shift $?
                ;;
            --switch-prefixes*)
                local params=$(parse_param "$@") || shift $?
                while read -d',' -r pair; do
                    if [[ -z "${pair%%:*}" ]]; then
                        SWITCH_PREFIXES["add"]=${pair##*:}
                    else
                        SWITCH_PREFIXES[${pair%%:*}]=${pair##*:}
                    fi
                done <<<"${params},"
                ;;
            --debug)
                DEBUG=0
                ;;
            -h | --help)
                usage
                exit 0
                ;;
            -[a-zA-Z][a-zA-Z]*)
                local i="${1:-}"
                shift
                for i in $(echo "$i" | grep -o '[a-zA-Z]'); do
                    set -- "-$i" "$@"
                done
                continue
                ;;
            --)
                shift
                POSARGS+=("$@")
                ;;
            -[a-zA-Z]* | --[a-zA-Z]*)
                die "Unrecognized argument ${1:-}"
                ;;
            *)
                POSARGS+=("${1:-}")
                ;;
        esac
        shift
    done
}

parse_param() {
    local param arg
    local -i toshift=0

    if (($# == 0)); then
        return $toshift
    elif [[ "$1" =~ .*=.* ]]; then
        param="${1%%=*}"
        arg="${1#*=}"
    elif [[ "${2-}" =~ ^[^-].+ ]]; then
        param="$1"
        arg="$2"
        ((toshift++))
    fi

    if [[ -z "${arg-}" && ! "${OPTIONAL-}" ]]; then
        die "${param:-$1} requires an argument"
    fi

    echo "${arg:-}"
    return $toshift
}

die() {
    exec 1>&2
    echo "$@"
    exit 1
}

main "$@"
