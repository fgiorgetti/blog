OPTSTRING=":d"
target_dir="content/posts"
create_dir=false

function exit_error() {
    echo $*
    exit 1
}

while getopts ${OPTSTRING} opt; do
    case ${opt} in
        d)
            create_dir=true
            ;;
    esac
done

if [[ ${OPTIND} -gt $# ]]; then
    echo "Usage: `basename $0` [-d] new-post-name"
    exit 1
fi

# Validating filename
filename=${@:$OPTIND:1}
! [[ "${filename}" =~ ^[a-zA-Z0-9-]+$ ]] && exit_error "Invalid filename. Use only letters, digits and dashes."

# Defining the definitive filename to use
if $create_dir; then
    target_dir+="/`date +%Y%m%d-`${filename}"
    final_name="${target_dir}/index.md"
else
    final_name="${target_dir}/`date +%Y%m%d-`${filename}.md"
fi

# Preventing a mess
[[ -f "${final_name}" ]]  && exit_error "Post already exist, use a different name"

# Creating the new blog post
hugo new ${final_name}
