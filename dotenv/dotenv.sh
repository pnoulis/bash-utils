#!/usr/bin/env bash

set -o errexit

EXECDIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)
PKGDIR=$EXECDIR
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
  3. loading of cmd envars
  4. expansion
  5. writting out the loaded environment

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

  --- 3. Loading of the command line or process enviroment
  Environment variables specified through the command line or are part of the
  parent process environment have the highest possible priority.
  The --mode is not consulted in this stage.

  Example:
  SOME_ENV=yolo ${0}

  --- 4. Expansion
  It is sometimes usefull to be able to construct an envar by referering other
  envars which may have been already defined or will be at some later loading stage.

  Example:
  SOME_ENV=basic
  SOME_ENV_EXPANDED=${SOME_ENV}_expansion
  SOME_ENV_DEFAULT=${MISSING_ENV:-yolo}_expansion

  * Notice how the expansion supports defaults in the case of a missing environment

  -- 5. Writting out the loaded environment.
  ${0} First truncates and then writes the loaded enviroment at the <project_root>/.env

  The project root is specified through the paramater --pkgdir.

[USAGE]: ${0} [OPTION]
    -m, --mode - config mode
             If --mode is not provided the script looks for a value
             through the process envar MODE
    --envdir - The root directory of the environment variable files
             or the process envar ENVDIR
    --pkgdir - The root directory of the package / application.
             or the process envar PKGDIR
    --envprefixes - a key value pair conforming to the syntax:
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
    # if [[ ! -d "${ENVDIR:-}" ]]; then
    #     die "envdir: ${ENVDIR} missing"
    # fi
    load_static_env
    load_local_env
    load_cmd_env
    filter_prefix
    # expand_envars
    # write_env
}

ensure_newline() {
    find . -mindepth 1 -type f -iregex '.*env.*' | xargs -I {} sed -i -e '$a\' {}
}

filter_prefix() {
    if (( "${#ENV_PREFIXES[@]}" == 0 )); then
        return
    fi
    local -A filtered=()
    for envar in "${!ENV[@]}"; do
        for filter in "${!ENV_PREFIXES[@]}"; do
            if [[ "${envar:-}" =~ .*${filter:-}.* ]]; then
                echo "${envar/${filter}/${ENV_PREFIXES[$filter]}}"
                filtered[$envar]=${ENV[$envar]}
            fi
            # if [[ "${filter:-}" == "${envar:-}" ]]; then
            #     echo $envar
            #     filtered[$envar]=${ENV[$envar]}
            #     continue
            # fi
        done
    done
    echo "${!filtered[@]}"
    echo "${filtered[@]}"
    # for i in "${!ENV_PREFIXES[@]}"; do
    #     if [[ "${i:-}" == "${1}" ]]; then
    #         return 0
    #     else
    #         return 1
    #     fi
    # done
}

expand_envars() {
    set -o allexport
    for i in "${!ENV[@]}"; do
        declare "${i}"=$(eval echo "${ENV[$i]}")
        ENV[$i]=$(eval echo "${ENV[$i]}")
    done
}

load_cmd_env() {
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
        development)
            if [[ -f './.env.development.local' ]]; then
                while IFS== read -r key value; do
                    if [[ -z "${key:-}" ]]; then
                        continue
                    fi
                    ENV["$key"]="$value"
                done < "./.env.development.local"
            fi
            ;;
        staging)
            if [[ -f './.env.staging.local' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./.env.staging.local"
            fi
            ;;
        production)
            if [[ -f './.env.production.local' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./.env.production.local"
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
        development)
            if [[ -f './env.development' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.development"
            fi
            ;;
        staging)
            if [[ -f './env.staging' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.staging"
            fi
            ;;
        production)
            if [[ -f './env.production' ]]; then
                while IFS== read -r key value; do
                    ENV[$key]=$value
                done < "./env.production"
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
                MODE=${MODE:-development}
                ;;
            --envdir*)
                ENVDIR=$(parse_param "$@") || shift $?
                ;;
            --envprefixes*)
                declare -gA ENV_PREFIXES=()
                local params=$(parse_param "$@") || shift $?
                while read -d',' -r pair; do
                    ENV_PREFIXES[${pair%%:*}]=${pair##*:}
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

