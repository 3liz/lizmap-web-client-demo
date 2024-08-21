#!/usr/bin/env python3

import argparse
import os
import shutil
from pathlib import Path
from shutil import copytree as copy_tree
from typing import Tuple

SCHEMAS = (
    'pgmetadata', 'pgmetadata_demo', 'demo_snapping', 'fire_hydrant_actions', 'observations', 'pgrouting_demo'
)

INSTALLATION_SQL = """This project is using some SQL data with a PostgreSQL service.

Please read the online documentation how to use SQL data.

https://github.com/3liz/lizmap-web-client-demo/blob/master/INSTALLATION.md

"""

JS_DOWNLOAD = """
lizMap.events.on({
    'uicreated': function(evt){
        var mediaLink = OpenLayers.Util.urlAppend(
            lizUrls.media,
            OpenLayers.Util.getParameterString(lizUrls.params)
        );
        mediaLink += '&path=/media/FOLDER.zip';
        $('#title').append(
            '<a class="btn btn-info" href="'+mediaLink+'" target="_blank"><i class="icon-download"></i>Download project</a>'
        );

        var script = document.createElement('script');
        script.setAttribute('src','SERVER');
        script.setAttribute('data-domain','DOMAIN');
        script.setAttribute('defer','');
        script.setAttribute('event-repository', lizUrls.params.repository);
        script.setAttribute('event-project', lizUrls.params.project);
        script.setAttribute('event-project-id', lizUrls.params.repository + '~' + lizUrls.params.project);
        script.setAttribute('event-language', navigator.language.toString().substr(0,2).toLowerCase());
        document.head.appendChild(script);
        window.plausible = window.plausible || function() { (window.plausible.q = window.plausible.q || []).push(arguments)}

        $('#button-attributeLayers').on('click', function(e) { plausible('AttributeTableOpened'); });
        $('#button-dataviz').on('click', function(e) { plausible('DatavizOpened'); });
    },

    'lizmapeditionformdisplayed': function(evt){
        // $('#jforms_view_edition').addClass("plausible-event-name--Form");
        $(document).ready(function() { $('#jforms_view_edition__submit_submit').on('click', function(e) { plausible('FormSaved'); }); });
    },

    'layersadded': function(e) {
        var html = '';
        html+= '<div class="modal-header"><a class="close" data-dismiss="modal">X</a><h3>Welcome on this map</h3></div>';

        html+= '<div class="modal-body">';
        html+= $('#metadata').html();
        html+= '</div>';

        html+= '<div class="modal-footer"><button type="button" class="btn btn-default" data-dismiss="modal">Ok</button></div>';

        $('#lizmap-modal').html(html).modal('show');
    }
});
"""


# def basename_from_project(qgis_project: str, directory: Path = Path()) -> str:
#
#     qgis_project_path = directory.absolute() / qgis_project
#     if not qgis_project_path.exists():
#         print(f'{qgis_project_path} does not exist. Exiting…')
#         exit(1)
#
#     base_name = qgis_project_path.stem
#     return base_name


# def project_related_files(qgis_project: Path) -> list:
#     """ Return a list of files related to the QGS project. """
#     files = list()
#     base_name = qgis_project.stem
#
#     parent_folder = qgis_project.parent
#     files.append(parent_folder / f'{base_name}.qgs')
#     files.append(parent_folder / f'{base_name}.qgs.cfg')
#
#     # Doc
#     markdown = parent_folder / f'{base_name}.md'
#     print(markdown.absolute())
#     if markdown.exists():
#         files.append(markdown)
#
#     # Thumbnail
#     jpg = Path(f'{base_name}.qgs.jpg')
#     if jpg.exists():
#         files.append(jpg)
#     else:
#         png = Path(f'{base_name}.qgs.png')
#         if png.exists():
#             files.append(png)
#
#     # Data
#     data = Path(f'data_{base_name}')
#     if data.exists():
#         files.extend(files_directory(data))
#
#     # Media
#     media = Path(f'media/js/{base_name}')
#     if media.exists():
#         files.extend(files_directory(media))
#
#     return files


# def files_directory(directory) -> list:
#     """ Return a list of files in given directory. """
#     values = list()
#     for root, dirs, files in os.walk(directory):
#         for file in files:
#             if file.startswith('_'):
#                 print(f'Skipping {file}…')
#                 continue
#
#             values.append(Path(f'{root}/{file}'))
#
#     return values


def main():
    parser = argparse.ArgumentParser()
    # parser.add_argument("-v", "--version", help="print the version and exit", action='store_true')

    subparsers = parser.add_subparsers(dest='command')

    # package
    package_parser = subparsers.add_parser(
        'package', help='creates a ZIP archive of the project in the media folder')
    package_parser.add_argument('QGS_PROJECT', help='The QGS project file name')

    # copy to dedicated git repo
    package_parser = subparsers.add_parser('copy', help='copy the project to a dedicated git repository')
    package_parser.add_argument('QGS_PROJECT', help='The QGS project file name')
    package_parser.add_argument('GIT_REPOSITORY_PATH', help='The Git repository on the file system')

    # copy to dedicated git repo
    package_parser = subparsers.add_parser('deploy', help='deploy the project to an FTP directory')
    package_parser.add_argument('FOLDER', help='The folder to deploy')
    package_parser.add_argument('DESTINATION', help='The FTP folder to deploy')

    package_parser = subparsers.add_parser('deploy-all', help='deploy all projects following the mapping file')
    package_parser.add_argument('DESTINATION', help='The FTP folder to deploy')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        parser.exit()

    if args.command == 'copy':
        pass
        # target = Path(args.GIT_REPOSITORY_PATH)
        # if not target.exists():
        #     print('Git repo does not exist')
        #     exit(1)
        #
        # basename = basename_from_project(args.QGS_PROJECT)
        # target = target.joinpath(basename)
        #
        # if not target.exists():
        #     print(f'The folder {basename} does not exist in the git repo')
        #     exit(1)
        #
        # files = project_related_files(basename)
        # for file in files:
        #     target_file = target.joinpath(file)
        #     if target_file.exists():
        #         print(f'Removing {target_file}')
        #         if target_file.is_file():
        #             target_file.unlink()
        #         else:
        #             shutil.rmtree(target_file)
        #
        #     if not target_file.parent.exists():
        #         Path(target_file.parent).mkdir(parents=True)
        #
        #     print(f'Copying {file} to {target_file}')
        #     shutil.copy(file, target_file)
        #
        #     if target_file.suffix == '.md':
        #         print('Renaming the markdown file')
        #         target_file.rename(Path(target_file.parent.joinpath('README.md')))

    elif args.command == 'deploy-all':
        if not os.getenv("LWC_INSTANCE"):
            print("No LWC_INSTANCE environment variable")
            exit(2)

        destination = Path(args.DESTINATION)

        for i in destination.iterdir():
            print(i)
        if any(destination.iterdir()):
            print("The destination is not empty.")
            exit(1)

        import csv
        with open('mapping.csv', newline='') as csvfile:
            reader = csv.DictReader(csvfile)

            psql = []
            for row in reader:
                destination_folder = destination / row['folder']
                if not destination_folder.exists():
                    Path(destination / row['folder']).mkdir()

                result, sql = deploy_project(row['project'], destination_folder)
                if not result:
                    exit(1)
                if sql:
                    psql.append(sql)

            print("FTP directory ready")
            if psql:
                service_name = read_service_name()
                schemas = [f'DROP SCHEMA IF EXISTS {i} CASCADE;' for i in SCHEMAS]
                with_print = (True, False)

                with open("demo_psql.sh", "w") as output:
                    output.write("# Autogenerated by the demo git repository\n")

                for i in with_print:
                    service = f" service={service_name} " if i else ""
                    if i:
                        print("Please run")

                    psql_lines = [
                        f"psql {service} -c \"{''.join(schemas)}\"",
                        f"psql {service} -c \"SELECT pg_catalog.setval('pgrouting.edges_id_seq', 1, true)\"",
                        f"psql {service} -c \"TRUNCATE pgrouting.nodes CASCADE; "
                        f"SELECT pg_catalog.setval('pgrouting.nodes_id_seq', 1, true)\"",
                        f"psql {service} -f {' -f '.join(psql)}",
                    ]
                    for sql_line in psql_lines:
                        if i:
                            print(sql_line)
                        else:
                            with open("demo_psql.sh", "a") as output:
                                output.write(sql_line + "\n")

    elif args.command == 'deploy':
        destination = Path(args.DESTINATION)
        project_name = args.FOLDER
        deploy_project(project_name, destination)


def deploy_project(project_name: str, destination: Path) -> Tuple[bool, str]:
    """Deploy a single project into a folder. """
    folder = Path(project_name)
    if project_name.endswith('/'):
        project_name = project_name[0:-1]

    print(f"Deploying {project_name} into {destination}\n")

    with open(Path(project_name) / f'{project_name}.qgs') as f:
        data = f.read()
    use_pg_service = "PG_SERVICE" in data
    print(f"\nCheck if the project is using a PG service : {use_pg_service}\n")

    if use_pg_service:
        service_name = read_service_name()

    print("Copying :")
    for from_file in folder.iterdir():

        if from_file.name.endswith('~'):
            continue

        if from_file.name.endswith(('.qgs.jpg', '.qgs.png', 'qgs', 'qgs.cfg', 'qgs.action',)):
            print(f"  file {from_file.name}")
            shutil.copy(from_file, destination)

            if from_file.name.endswith('.qgs') and use_pg_service:
                print("Replace the service")
                with open(destination / from_file.name, 'r') as f:
                    data = f.read()

                data = data.replace("PG_SERVICE", service_name)

                with open(destination / from_file.name, 'w') as f:
                    f.write(data)

        if from_file.name.startswith('data') and from_file.is_dir():
            print(f"  data folder {from_file.name}")
            Path(destination / from_file.name).mkdir(parents=True)

            for data_file in from_file.iterdir():
                if data_file.name.endswith(('-shm', '-wal',)):
                    continue

                print(data_file.name)
                if data_file.is_file():
                    shutil.copy(
                        str(data_file),
                        str(destination / from_file.name),
                    )
                else:
                    copy_tree(
                        str(data_file),
                        str(destination / from_file.name),
                        dirs_exist_ok=True,
                    )

        if from_file.name == 'media' and from_file.is_dir():
            for media_file in from_file.iterdir():
                if media_file.name == 'js':
                    print("  JS media folder")
                    destination_js = destination / 'media' / 'js'
                    if not destination_js.exists():
                        destination_js.mkdir(parents=True)

                    copy_tree(
                        str(media_file),
                        str(destination_js),
                        dirs_exist_ok=True,
                    )
                elif media_file.name.startswith("data_"):
                    print(f"  media folder related to this project : {media_file}")
                    destination_media = destination / 'media' / f"data_{project_name}"
                    copy_tree(
                        str(media_file),
                        str(destination_media),
                        dirs_exist_ok=True,
                    )
                elif media_file.name == 'upload':
                    print(f"  upload media folder related to this project : {media_file}")
                    destination_media = destination / 'media' / "upload"
                    copy_tree(
                        str(media_file),
                        str(destination_media),
                        dirs_exist_ok=True,
                    )

    print("\n")
    # Generate zip
    print("Generating ZIP file :")

    destination_folder = destination / 'media' / 'js' / project_name
    destination_folder.mkdir(exist_ok=True, parents=True)

    with open(folder / 'INSTALLATION.md', 'w') as f:
        f.write(INSTALLATION_SQL)

    tilde = Path(folder / f'{project_name}.qgs~')
    if tilde.exists():
        tilde.unlink()

    side_zip = Path(folder / f'{project_name}_attachments.zip')
    if side_zip.exists():
        side_zip.unlink()

    shutil.make_archive(str(destination / 'media' / f'{project_name}'), 'zip', str(folder))

    download_file = destination_folder / '_download.js'
    print(f"\nGenerating JS file {download_file}")
    with open(download_file, 'w') as f:
        js_content = str(JS_DOWNLOAD)
        js_content = js_content.replace('FOLDER', project_name)
        js_content = js_content.replace('SERVER', 'https://bourbon.3liz.com/js/script.pageview-props.tagged-events.js')
        js_content = js_content.replace('DOMAIN', 'demo.lizmap.com')
        f.write(js_content)

    psql = ''
    if use_pg_service:
        print("\nDo not forget to run")
        psql = f"{project_name}/sql/data.sql"
        print(f"psql service={service_name} -f {psql}")

    print("\nEnd !")
    return True, psql


def read_service_name() -> str:
    service_name = os.getenv("PG_SERVICE")
    if service_name:
        return service_name

    print('No PG_SERVICE environment variable detected')

    try:
        from env import SERVERS
    except ImportError:
        print("No env.py files, quit")
        exit(1)

    print("Checking instance name LWC_INSTANCE from environment variable")
    lwc_instance = os.getenv("LWC_INSTANCE")
    if not lwc_instance:
        lwc_instance = os.getenv("INSTANCE")
    if not lwc_instance:
        print("No LWC_INSTANCE environment variable (or INSTANCE as a fallback as well)")
        exit(2)

    if lwc_instance not in SERVERS.keys():
        print(f"Unknown server {lwc_instance} in your own configuration file")
        exit(3)

    service_name = SERVERS.get(lwc_instance).service
    if not service_name:
        print(f"No service found for {lwc_instance}")
        exit(4)

    return service_name


if __name__ == "__main__":
    exit(main())
