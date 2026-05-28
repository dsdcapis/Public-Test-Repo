#!/bin/bash
set -e

currentFolder="$(pwd)"
publicFolder="$currentFolder/public"

findAllFiles() {
    local -n resultRef=$1

    while IFS= read -r -d '' dir; do
        rel_dir="${dir#$currentFolder/}"
        resultRef["$rel_dir"]="openapi"
    done < <(find "$currentFolder" -type f -name "openapi.yaml" -print0 | xargs -0 -n1 dirname -z | sort -zu)

    while IFS= read -r -d '' file; do
        rel_file="${file#$currentFolder/}"
        resultRef["$rel_file"]="pdf"
    done < <(find "$currentFolder" -type f -name "*.pdf" -print0 | sort -z)

    while IFS= read -r -d '' file; do
        rel_file="${file#$currentFolder/}"
        resultRef["$rel_file"]="xlsx"
    done < <(find "$currentFolder" -type f -name "*.xlsx" -print0 | sort -z)
}

loadStaticHtmlToFolder() {
    local folder="$1"

    echo "Creating folder \"$publicFolder/$folder\""
    mkdir -p "$publicFolder/$folder"

    echo "Bundling OpenAPI spec: \"$currentFolder/$folder/openapi.yaml\""
    npx @redocly/cli@latest bundle "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/openapi-combined.yaml" --ext yaml

    echo "Building docs: \"$currentFolder/$folder/openapi.yaml\""
    npx @redocly/cli@latest build-docs "$currentFolder/$folder/openapi.yaml" -o "$publicFolder/$folder/index.html" --theme.openapi.downloadDefinitionUrl="openapi-combined.yaml"
}

generateHighLevelIndex() {
    local indexFile="$publicFolder/index.html"

    cat > "$indexFile" << 'ENDHEAD'
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>LTL API Documentation - Test</title>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/jszip/3.10.1/jszip.min.js"></script>
    <script charset="utf-8" type="text/javascript" src="//js.hsforms.net/forms/embed/v2.js"></script>
</head>
<style>
    body {
        font-family: Arial, sans-serif;
        margin: 20px;
        padding-bottom: 80px;
    }
    p {
        max-width: 720px;
        line-height: 1.6;
    }
    img.logo {
        max-height: 100px;
        margin-top: 10px;
        margin-bottom: 10px;
    }
    .tree {
        list-style-type: none;
        padding-left: 0;
    }
    .tree ul {
        list-style-type: none;
        padding-left: 20px;
        margin: 0;
    }
    .tree li {
        margin: 3px 0;
        position: relative;
    }
    .folder {
        font-weight: bold;
        color: #333;
        cursor: pointer;
        user-select: none;
    }
    .folder::before {
        content: '📁 ';
        margin-right: 5px;
    }
    .folder.collapsed::before {
        content: '📂 ';
    }
    .file-link {
        text-decoration: none;
        padding: 2px 4px;
        border-radius: 3px;
        transition: background-color 0.2s;
    }
    .file-link:hover {
        background-color: #f0f0f0;
    }
    .pdf-link {
        color: #d9534f;
    }
    .pdf-link::before {
        content: '📄 ';
        margin-right: 5px;
    }
    .xlsx-link {
        color: #5cb85c;
    }
    .xlsx-link::before {
        content: '📊 ';
        margin-right: 5px;
    }
    .openapi-link {
        color: #5bc0de;
    }
    .openapi-link::before {
        content: '📋 ';
        margin-right: 5px;
    }
    .toggle {
        display: inline-block;
        width: 16px;
        text-align: center;
        cursor: pointer;
        user-select: none;
        margin-right: 3px;
    }
    .hidden {
        display: none;
    }
    .download-checkbox {
        margin-right: 6px;
        cursor: pointer;
        width: 14px;
        height: 14px;
        vertical-align: middle;
    }
    #download-btn {
        display: none;
        position: fixed;
        bottom: 24px;
        right: 24px;
        background-color: #337ab7;
        color: white;
        border: none;
        padding: 12px 24px;
        border-radius: 6px;
        font-size: 15px;
        cursor: pointer;
        box-shadow: 0 2px 8px rgba(0,0,0,0.3);
        z-index: 100;
    }
    #download-btn:hover {
        background-color: #286090;
    }
    #download-modal {
        display: none;
        position: fixed;
        top: 0; left: 0; right: 0; bottom: 0;
        background: rgba(0,0,0,0.5);
        z-index: 200;
        align-items: center;
        justify-content: center;
    }
    .modal-box {
        background: white;
        border-radius: 8px;
        padding: 30px;
        max-width: 520px;
        width: 90%;
        position: relative;
        max-height: 90vh;
        overflow-y: auto;
    }
    .modal-box h2 {
        margin-top: 0;
        font-size: 18px;
    }
    .modal-close {
        position: absolute;
        top: 12px;
        right: 16px;
        background: none;
        border: none;
        font-size: 20px;
        cursor: pointer;
        color: #666;
    }
    #download-toast {
        display: none;
        position: fixed;
        bottom: 24px;
        left: 50%;
        transform: translateX(-50%);
        background: #5cb85c;
        color: white;
        padding: 12px 24px;
        border-radius: 6px;
        font-size: 14px;
        z-index: 300;
        box-shadow: 0 2px 8px rgba(0,0,0,0.2);
    }
</style>
<body>
    <img class="logo" src="images/DSDC-LTL.svg" alt="Company Logo">
    <p>Supported by the Digital Standard Development Council's (DSDC) Digital LTL Council, these API standards help organizations modernize LTL workflows through standardized, open, and scalable integration.</p>
    <h1>LTL API Documentation - Test</h1>
    <ul class="tree" id="root">
ENDHEAD

    # Sort all paths for processing
    local sortedPaths=()
    for path in "${!allFiles[@]}"; do
        sortedPaths+=("$path")
    done
    IFS=$'\n' sortedPaths=($(sort <<< "${sortedPaths[*]}"))
    unset IFS

    # Copy PDF and XLSX files
    for path in "${sortedPaths[@]}"; do
        local fileType="${allFiles[$path]}"
        if [[ "$fileType" == "pdf" || "$fileType" == "xlsx" ]]; then
            local fileDir=$(dirname "$path")
            mkdir -p "$publicFolder/$fileDir"
            cp "$currentFolder/$path" "$publicFolder/$path"
        fi
    done

    # Build complete tree structure
    declare -A treeNodes
    declare -a topLevel

    for path in "${sortedPaths[@]}"; do
        IFS='/' read -ra parts <<< "$path"
        local currentPath=""

        for ((i=0; i<${#parts[@]}-1; i++)); do
            local part="${parts[$i]}"
            if [[ -n "$currentPath" ]]; then
                currentPath="$currentPath/$part"
            else
                currentPath="$part"
            fi

            if [[ -z "${treeNodes[$currentPath]}" ]]; then
                treeNodes["$currentPath"]="folder"

                if [[ $i -eq 0 ]]; then
                    topLevel+=("$currentPath")
                fi
            fi
        done

        treeNodes["$path"]="${allFiles[$path]}"
    done

    IFS=$'\n' topLevel=($(sort -u <<< "${topLevel[*]}"))
    unset IFS

    printTree() {
        local prefix="$1"
        local indent="$2"

        local items=()
        for path in "${sortedPaths[@]}"; do
            if [[ -z "$prefix" ]]; then
                IFS='/' read -ra parts <<< "$path"
                local firstPart="${parts[0]}"
                items+=("$firstPart")
            elif [[ "$path" == "$prefix"* ]]; then
                local remainder="${path#$prefix/}"
                if [[ "$remainder" != */* ]]; then
                    items+=("$path")
                else
                    IFS='/' read -ra parts <<< "$remainder"
                    local nextPart="$prefix/${parts[0]}"
                    items+=("$nextPart")
                fi
            fi
        done

        IFS=$'\n' items=($(sort -u <<< "${items[*]}"))
        unset IFS

        for item in "${items[@]}"; do
            local nodeType="${treeNodes[$item]}"

            if [[ "$nodeType" == "folder" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local folderName="${parts[-1]}"

                echo "${indent}<li>" >> "$indexFile"
                echo "${indent}    <span class=\"toggle\" onclick=\"toggleFolder(this)\">▼</span>" >> "$indexFile"
                echo "${indent}    <span class=\"folder\">$folderName</span>" >> "$indexFile"
                echo "${indent}    <ul>" >> "$indexFile"

                printTree "$item" "$indent    "

                echo "${indent}    </ul>" >> "$indexFile"
                echo "${indent}</li>" >> "$indexFile"

            elif [[ "$nodeType" == "openapi" ]]; then
                if [[ -f "$publicFolder/$item/index.html" ]]; then
                    IFS='/' read -ra parts <<< "$item"
                    local fileName="${parts[-1]}"
                    echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" data-file=\"${item}/openapi-combined.yaml\" data-name=\"${item}/openapi-combined.yaml\" onchange=\"updateSelection()\"><a class=\"file-link openapi-link\" href=\"$item/index.html\">$fileName (OpenAPI)</a></li>" >> "$indexFile"
                fi

            elif [[ "$nodeType" == "pdf" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local fileName="${parts[-1]}"
                echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" data-file=\"$item\" data-name=\"$item\" onchange=\"updateSelection()\"><a class=\"file-link pdf-link\" href=\"$item\" onclick=\"handleDownloadClick(event); return false;\">$fileName</a></li>" >> "$indexFile"

            elif [[ "$nodeType" == "xlsx" ]]; then
                IFS='/' read -ra parts <<< "$item"
                local fileName="${parts[-1]}"
                echo "${indent}<li><input type=\"checkbox\" class=\"download-checkbox\" data-file=\"$item\" data-name=\"$item\" onchange=\"updateSelection()\"><a class=\"file-link xlsx-link\" href=\"$item\" onclick=\"handleDownloadClick(event); return false;\">$fileName</a></li>" >> "$indexFile"
            fi
        done
    }

    printTree "" "        "

    cat >> "$indexFile" << 'ENDSCRIPT'
    </ul>

    <button id="download-btn" onclick="openDownloadModal()">
        Download Selected (<span id="download-count">0</span>)
    </button>

    <div id="download-modal">
        <div class="modal-box">
            <button class="modal-close" onclick="closeDownloadModal()">&#x2715;</button>
            <h2>Please fill out the form to download</h2>
            <div id="hubspot-form-container"></div>
        </div>
    </div>

    <div id="download-toast">&#x2713; Download complete</div>

    <script>
        var selectedFiles = [];

        function updateSelection() {
            selectedFiles = [];
            document.querySelectorAll('.download-checkbox:checked').forEach(function(cb) {
                selectedFiles.push({ path: cb.dataset.file, name: cb.dataset.name });
            });
            var btn = document.getElementById('download-btn');
            document.getElementById('download-count').textContent = selectedFiles.length;
            btn.style.display = selectedFiles.length > 0 ? 'block' : 'none';
        }

        function handleDownloadClick(event) {
            event.preventDefault();
            var cb = event.currentTarget.closest('li').querySelector('.download-checkbox');
            if (cb && !cb.checked) {
                cb.checked = true;
                updateSelection();
            }
            openDownloadModal();
        }

        function openDownloadModal() {
            if (selectedFiles.length === 0) return;
            if (typeof hbspt === 'undefined') {
                alert('Form is loading, please try again in a moment.');
                return;
            }

            var filesToDownload = selectedFiles.slice();
            var fileList = filesToDownload.map(function(f) {
                return f.name.split('/').pop();
            }).join(', ');

            var container = document.getElementById('hubspot-form-container');
            container.innerHTML = '';

            hbspt.forms.create({
                portalId: '22203423',
                formId: 'dcd7e162-7c2b-457c-a40e-1c6e65c1edea',
                target: '#hubspot-form-container',
                onFormSubmit: function($form) {
                    var hiddenField = $form[0].querySelector('input[name="dsdc_apis_downloaded"]');
                    if (hiddenField) {
                        hiddenField.value = fileList;
                        hiddenField.dispatchEvent(new Event('change', { bubbles: true }));
                        hiddenField.dispatchEvent(new Event('input', { bubbles: true }));
                    }
                },
                onFormSubmitted: function() {
                    closeDownloadModal();
                    downloadAsZip(filesToDownload);
                    document.querySelectorAll('.download-checkbox:checked').forEach(function(cb) {
                        cb.checked = false;
                    });
                    updateSelection();
                }
            });

            document.getElementById('download-modal').style.display = 'flex';
        }

        function closeDownloadModal() {
            document.getElementById('download-modal').style.display = 'none';
        }

        async function downloadAsZip(files) {
            var zip = new JSZip();
            var fetchPromises = files.map(function(file) {
                return fetch(file.path)
                    .then(function(r) { return r.blob(); })
                    .then(function(blob) { zip.file(file.name, blob); });
            });
            await Promise.all(fetchPromises);
            var content = await zip.generateAsync({ type: 'blob' });
            var url = URL.createObjectURL(content);
            var a = document.createElement('a');
            a.href = url;
            a.download = 'dsdc-ltl-specs.zip';
            document.body.appendChild(a);
            a.click();
            document.body.removeChild(a);
            URL.revokeObjectURL(url);
            showToast();
        }

        function showToast() {
            var toast = document.getElementById('download-toast');
            toast.style.display = 'block';
            setTimeout(function() { toast.style.display = 'none'; }, 3000);
        }

        function toggleFolder(toggle) {
            var li = toggle.parentElement;
            var ul = li.querySelector('ul');
            if (ul) {
                ul.classList.toggle('hidden');
                toggle.textContent = ul.classList.contains('hidden') ? '▶' : '▼';
            }
        }

        document.addEventListener('DOMContentLoaded', function() {
            document.querySelectorAll('.folder').forEach(function(folder) {
                folder.addEventListener('dblclick', function() {
                    var toggle = this.previousElementSibling;
                    if (toggle && toggle.classList.contains('toggle')) {
                        toggleFolder(toggle);
                    }
                });
            });
        });
    </script>
</body>
</html>
ENDSCRIPT
    echo "Created high level index at \"$indexFile\""
}

copyImages() {
    echo "Copying images..."
    mkdir -p "$publicFolder/images"
    cp "$currentFolder/images/DSDC-LTL.svg" "$publicFolder/images/"
}

mainProcess() {
    echo "Removing existing public folder..."
    rm -rf "$publicFolder"

    declare -A allFiles
    findAllFiles allFiles

    for path in "${!allFiles[@]}"; do
        if [[ "${allFiles[$path]}" == "openapi" ]]; then
            echo "Processing OpenAPI directory: \"$path\""
            loadStaticHtmlToFolder "$path"
        fi
    done

    generateHighLevelIndex
    copyImages
}

mainProcess
