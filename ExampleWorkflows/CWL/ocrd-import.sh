#!/usr/bin/env bash
# Source: https://github.com/bertsky/workflow-configuration/blob/master/ocrd-import

function log {
    echo >&2 "$(date +%T.%3N) $LEVEL ocrd-import - $1"
}
function critical { LEVEL=CRITICAL log "$1"; }
function error { LEVEL=ERROR log "$1"; }
function warning { LEVEL=WARNING log "$1"; }
function info { LEVEL=INFO log "$1"; }
function debug { LEVEL=DEBUG log "$1"; }

((BASH_VERSINFO<4 || BASH_VERSINFO==4 && BASH_VERSINFO[1]<4)) && critical "bash $BASH_VERSION is too old. Please install 4.4 or newer" && exit 2

ignore=0
skip=()
convert=1
dpi=300
numpageid=1
while (($#)); do
    case "${1:--h}" in
        -h|-[-]help)
            cat <<EOF
Usage: $(basename $0) [OPTIONS] [DIRECTORY]
with options:
 -i|--ignore      keep going after unknown file types
 -s|--skip SUFFIX ignore file names ending in given SUFFIX
 -C|--no-convert  do not attempt to convert image file types
 -r|--render DPI  when converting PDFs, render at DPI pixel density
 -P|--nonnum-ids  do not use numeric pageIds but basename patterns
Create OCR-D workspace meta-data (mets.xml) in DIRECTORY (or $PWD), importing...
* all image files (with known file extension or convertible via ImageMagick) under fileGrp OCR-D-IMG
* all .xml files (if they validate as PAGE-XML) under fileGrp OCR-D-SEG-PAGE
...but failing otherwise.
EOF
            exit
            ;;
        -i|--ignore)
            ignore=1
            shift
            ;;
        -s|--skip)
            shift
            skip+=("$1")
            shift
            ;;
        -C|--no-convert)
            convert=0
            shift
            ;;
        -r|--render)
            shift
            dpi="$1"
            [[ "$dpi" =~ [0-9]+ ]] || {
                critical "--render needs a numeric value"
                exit 2
            }
            shift
            ;;
        -P|--nonnum-ids)
            numpageid=0
            shift
            ;;
        *)
            break
            ;;
    esac
done

(($#>1)) && warning "non-first argument(s) will be ignored: '${@:2}'"

function add_file {
    info "adding -G $1 -m $2 -g $3 -i $4 '$5'"
    ocrd workspace add -G $1 -m $2 -g $3 -i "$4" "$5"
}

set -e
declare -A MIMETYPES
eval MIMETYPES=( $(ocrd bashlib constants EXT_TO_MIME) )
MIMETYPE_PAGE=$(ocrd bashlib constants MIMETYPE_PAGE)
DIRECTORY="${1:-.}"
test -d "$DIRECTORY"

# avoid damaging/replacing existing workspaces:
if test -f "$DIRECTORY"/mets.xml || test -d "$DIRECTORY"/data -a -f "$DIRECTORY"/data/mets.xml; then
    error "Directory '$1' already is a workspace"
    exit 1
fi

# sub-shell to back-off from mets.xml and subdir in case of failure:
set +e
(
set -e
cd "$DIRECTORY"
ocrd workspace init
num=0 zeros=0000
IFS=$'\n'
for file in $(find -L . -type f -not -name mets.xml -not -name "*.log" | sort); do
    IFS=' \t\n'
    let num++
    page=p${zeros:0:$((4-${#num}))}$num
    group=OCR-D-IMG
    file="${file#./}"
    for suffix in "${skip[@]}"; do
        if test "$file" != "${file%$suffix}"; then
            info "skipping file '$file'"
            file=
            break
        fi
    done
    test -z "$file" && continue
    # guess MIME type
    name="$(basename "$file")"
    suffix=."${name##*.}"
    base="${name%$suffix}"
    # XSD ID must start with letter and not contain colons or spaces
    base="${base//[ :]/_}"
    if ! [[ ${base:0:1} =~ [a-zA-Z] ]]; then
        base=f${base}
    fi
    if !((numpageid)); then
        page=$base
        # file ID must contain group, or processors will have to
        # prevent ID clashes by using numeric IDs
        base=${group}_"$base"
    fi
    mimetype=${MIMETYPES[${suffix,,[A-Z]}]}
    #debug "found file '$file' (base=$base page=$page mimetype=$mimetype)"
    case "$mimetype" in
        ${MIMETYPE_PAGE})
        # FIXME should really validate this is PAGE-XML (cf. core#353)
        if fgrep -q http://schema.primaresearch.org/PAGE/gts/pagecontent/ "$file" \
           && fgrep -qw 'PcGts' "$file"; then
            group=OCR-D-SEG-PAGE
            if !((numpageid)); then
                base=${base/OCR-D-IMG/$group}
            fi
        elif fgrep -q http://www.loc.gov/standards/alto/ "$file" \
                && fgrep -qw alto "$file"; then
            group=OCR-D-SEG-ALTO
            if !((numpageid)); then
                base=${base/OCR-D-IMG/$group}
            fi
        elif (($ignore)); then
            warning "unknown type of file '$file'"
            continue
        else
            error "unknown type of file '$file'"
            exit 1
        fi
        ;;
        application/pdf|application/postscript|application/oxps|image/x-*|"")
        case "$suffix" in
            .pdf|.PDF)
                inopts=(-density $((2*$dpi)) -units PixelsPerInch)
                outopts=(-background white -alpha remove -alpha off -resample $dpi -density $dpi -units PixelsPerInch)
                ;;
            *)
                inopts=()
                outopts=()
        esac
        if (($convert)) && \
               mkdir -p OCR-D-IMG && \
               warning "converting '$file' to 'OCR-D-IMG/${base}_*.tif' prior to import" && \
               convert "${inopts[@]}" "$file" "${outopts[@]}" OCR-D-IMG/"${base}_%04d.tif"; then
            mimetype=image/tiff
            IFS=$'\n'
            files=($(find OCR-D-IMG -name "${base}_[0-9]*.tif" | sort))
            IFS=$' \t\n'
            info "converted '$file' to 'OCR-D-IMG/${base}_*.tif' (${#files[*]} files)"
            if ((${#files[*]}>1)); then
                for file in "${files[@]}"; do
                    file="${file#./}"
                    base="${file%.tif}"
                    base="${base#OCR-D-IMG/}"
                    add_file $group $mimetype ${page}_${base:(-4)} "$base" "$file"
                done
                # there's no danger of clashes with other files here
                continue
            else
                file="${files[0]}"
                file="${file#./}"
            fi
        elif (($ignore)); then
            warning "unknown type of file '$file'"
            continue
        else
            error "unknown type of file '$file'"
            exit 1
        fi
        ;;
    esac
    IFS=$'\n'
    clashes=($(ocrd workspace find -i "$base" -k local_filename -k mimetype -k pageId))
    IFS=$' \t\n'
    n=0
    for clash in "${clashes[@]}"; do
        let n++
        IFS=$'\t'
        fields=($clash)
        IFS=$' \t\n'
        # if image, allow PAGE with matching basename
        # if PAGE, allow image with matching basename
        if if test $group = OCR-D-IMG; then
               test "x${fields[1]}" = x${MIMETYPE_PAGE}
           else [[ "${fields[1]}" =~ image/ ]]
           fi; then
            # use existing pageId
            page=${fields[2]}
            # use new file ID
            base="$(basename "$file")" # (including suffix)
            base="${base// /_}"
        else
            warning "files '$file' ($mimetype) and '${fields[0]}' (${fields[1]}) have the same basename"
        fi
    done
    # finally, add the file to the METS
    add_file $group $mimetype $page "$base" "$file"
done

# ensure these exist in the file system, too
# (useful for ocrd-make)
mkdir -p OCR-D-IMG OCR-D-SEG-PAGE
) || {
    rm -f "$DIRECTORY"/mets.xml
    critical "Cancelled '$DIRECTORY'"
    exit 2
}

info "Success on '$DIRECTORY'"
