filename=$1

function exit_error() {
    echo $*
    exit 1
}

# Validating filename
! [[ "${filename}" =~ ^[a-zA-Z0-9-]+$ ]] && exit_error "Invalid filename. Use only letters, digits and dashes."

# Defining the definitive filename to use
final_name="`date +%Y%m%d-`${filename}"

# Preventing a mess
[[ -f "${final_name}" ]] && exit_error "Post already exist, use a different name"

# Creating the new blog post
hugo new content/posts/${final_name}.md
