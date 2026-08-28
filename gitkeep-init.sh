#!/bin/bash
# gitkeep-init.sh — mark the initial repo structure with .gitkeep files.
#
# Usage:
#   gitkp [run|dry-run] [-c [MESSAGE]] [--force-root PATH ...]
#   gitkp undo
#   gitkp help

DIR_SOURCE=$( readlink -f "$( dirname "${BASH_SOURCE[0]}" )" )

shopt -s extglob

function gitkp()
{
    parse_options "${@:-}" || return 0

    if [[ "$UNDO" == "true" ]]; then
        uncommit_last_gitkeep_commit
    fi

    while IFS= read -r -d '' d; do
        process_directory "$d"
    done < <(collect_directories)

    if [[ "$COMMIT" == "true" ]]; then
        commit_gitkeeps
    fi

    echo "Done."
}

# if the last commit was made by run -c (only .gitkeep files),
# undo it: unstage and let the following loop remove them.
# If there are later commits or other files, do nothing.
function uncommit_last_gitkeep_commit()
{
    if ! is_gitkeep_commit; then
        return
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would reset: uncommit the last .gitkeep commit"
        return
    fi

    if git rev-parse --verify HEAD~1 >/dev/null 2>&1; then
        git reset HEAD~1
    else
        git update-ref -d HEAD
        git reset -q
    fi

    echo "  reset: uncommitted the last .gitkeep commit"
}

# true if the last commit contains only .gitkeep files
function is_gitkeep_commit()
{
    git rev-parse --verify HEAD >/dev/null 2>&1 || return 1

    local file
    while IFS= read -r file; do
        [[ "$file" == *.gitkeep ]] || return 1
    done < <(git show --name-only --format= HEAD 2>/dev/null)

    return 0
}

function parse_options()
{
    DRY_RUN=false
    UNDO=false
    COMMIT=false
    FORCES=()

    local one="${1/+(-h|--help|help|h)/help}"
    local two="${2/+(-h|--help|help|h)/help}"

    if [[ $one == "help" || $two == "help" ]]; then
        gitkp_help "$2"
        return 1
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            dry-run)         DRY_RUN=true;  shift ;;
            run)             DRY_RUN=false; shift ;;
            undo)            UNDO=true;     shift ;;
            -c|--commit)
                COMMIT=true
                take_optional_message "$@" && shift 2 || shift
                ;;
            --force-root)    add_force_root_path "$2" || return 1
                             shift 2 ;;
            *)               gitkp_help; return 1 ;;
        esac
    done
}

function gitkp_help()
{
    local subcommand="${1:-default}"

    subcommand="${subcommand//+(-h|--help|help|h)/default}"

    print_help_section "$subcommand"
}

function print_help_section()
{
    local name="$1"

    sed -n "/^:$name:/,/^:_$name:/p" "$DIR_SOURCE/helps.txt" \
        | grep -v '^:'
}

function add_force_root_path()
{
    local path="$1"

    [[ -n "$path" ]] || { echo "--force-root requires PATH" >&2; return 1; }

    FORCES+=("$path")
}

# take the next argument as the commit message if it is not a flag
function take_optional_message()
{
    COMMIT_MESSAGE="Generate initial structure with .gitkeep files"

    if [[ $# -gt 1 && "$2" != -* ]]; then
        COMMIT_MESSAGE="$2"
        return 0
    fi
    return 1
}

function collect_directories()
{
    build_prune_conditions

    find . -type d \( "${PRUNES[@]}" \) -prune -o -type d -print0
}

# build the conditions that tell find which directories to skip:
# .git, everything git ignores, and the interior of every --force-root
function build_prune_conditions()
{
    PRUNES=(-name .git -o -exec git check-ignore -q {} \;)

    for s in "${FORCES[@]}"; do
        PRUNES+=(-o -path "./$s/*")
    done
}

function process_directory()
{
    local d=$( normalize_path "$1" )

    if is_forced_root "$d"; then
        apply_gitkeep "$d"
        return
    fi

    has_tracked_subdirectories "$d" && return

    apply_gitkeep "$d"
}

function normalize_path()
{
    echo "${1#./}"
}

function is_forced_root()
{
    for s in "${FORCES[@]}"; do
        [[ "$1" == "$s" ]] && return 0
    done
    return 1
}

# true if the directory has subdirectories that git would track
# (ignored subdirectories don't count: the dir would be empty in git)
function has_tracked_subdirectories()
{
    local sub

    for sub in "$1"/*/; do
        [[ -d "$sub" ]] || continue
        is_ignored_by_git "${sub%/}" || return 0
    done
    
    return 1
}

# create or remove the .gitkeep according to the action (run/undo)
function apply_gitkeep()
{
    local dir="$1"

    if [[ "$UNDO" == "true" ]]; then
        gitkeep_action remove "$dir"
    else
        is_ignored_by_git "$dir" || gitkeep_action create "$dir"
    fi
}

# do one action on a .gitkeep: create or remove
function gitkeep_action()
{
    local action="$1"
    local dir="$2"
    local file="$dir/.gitkeep"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would $action: $file"
        return
    fi

    if [[ "$action" == "remove" ]] && is_committed "$file"; then
        echo "  skipped:     $file (already committed)"
        return
    fi

    [[ "$action" == "create" ]] && touch "$file" || rm -f "$file"
    echo "  ${action}d:      $file"
}

# true if the file exists in the last commit
function is_committed()
{
    git cat-file -e "HEAD:$1" 2>/dev/null
}

function is_ignored_by_git()
{
    git check-ignore -q "$1/.gitkeep"
}

function commit_gitkeeps()
{
    if [[ "$DRY_RUN" == "true" ]]; then
        echo "  would commit: $COMMIT_MESSAGE"
        return
    fi

    git add $( find . -name .gitkeep -not -path './.git/*' )

    git commit -m "$COMMIT_MESSAGE"
}

# run only when executed as a script (not when sourced from ~/.bashrc)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    gitkp "${@:-}"
fi

# bash autocompletion for gitkp
function _gitkp_complete()
{
    local latest="${COMP_WORDS[$COMP_CWORD]}"

    local prev="${COMP_WORDS[$COMP_CWORD - 1]}"

    case "$prev" in
        --force-root)
            COMPREPLY=( $( compgen -d -- "$latest" ) )
            ;;
        *)
            COMPREPLY=( $( compgen -W "run dry-run undo help -c --commit --force-root" -- "$latest" ) )
            ;;
    esac
}

complete -F _gitkp_complete gitkp gitkeep-init.sh
