#!/usr/bin/env python3

import argparse
import os
import shutil
from pathlib import Path
from distutils.dir_util import copy_tree


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
    },

    'layersadded': function(e) {
        var html = '';
        html+= '<div class="modal-header"><a class="close" data-dismiss="modal">Ã—</a><h3>Welcome on this map</h3></div>';

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

    elif args.command == 'deploy':
        destination = Path(args.DESTINATION)
        folder = Path(args.FOLDER)
        project_name = args.FOLDER
        if project_name.endswith('/'):
            project_name = project_name[0:-1]

        print(f"Deploying {project_name} into {destination}\n")

        with open(Path(project_name) / f'{project_name}.qgs') as f:
            data = f.read()
        use_pg_service = "PG_SERVICE" in data
        print(f"\nCheck if the project is using a PG service : {use_pg_service}\n")

        service_name = os.getenv("PG_SERVICE")

        print("Copying :")
        for a_file in folder.iterdir():

            if a_file.name.endswith('~'):
                continue

            if a_file.name.endswith(('jpg', 'png', 'qgs', 'qgs.cfg',)):
                print(f"  file {a_file.name}")
                shutil.copy(a_file, destination)

                if a_file.name.endswith('.qgs') and use_pg_service:
                    print("Replace the service")
                    with open(destination / a_file.name, 'r') as f:
                        data = f.read()

                    data = data.replace("PG_SERVICE", service_name)

                    with open(destination / a_file.name, 'w') as f:
                        f.write(data)

            if a_file.name.startswith('data') and a_file.is_dir():
                print(f"  data folder {a_file.name}")
                copy_tree(str(a_file), str(destination / a_file.name))

            if a_file.name == 'media' and a_file.is_dir():
                print("  media folder")
                for media_file in a_file.iterdir():
                    if media_file.name == 'js':
                        destination_js = destination / 'media' / 'js'
                        if not destination_js.exists():
                            destination_js.mkdir(parents=True)

                        copy_tree(str(media_file), str(destination_js))

        print("\n")
        # Generate zip
        print("Generating ZIP file :")

        destination_folder = destination / 'media' / 'js' / project_name
        destination_folder.mkdir(exist_ok=True, parents=True)

        shutil.make_archive(str(destination / 'media' / f'{project_name}'), 'zip', str(folder))

        download_file = destination_folder / '_download.js'
        print(f"\nGenerating JS file {download_file}")
        with open(download_file, 'w') as f:
            f.write(JS_DOWNLOAD.replace('FOLDER', project_name))

        if use_pg_service:
            print("\nDo not forget to run")
            print(f"psql service={service_name} -f {project_name}/sql/data.sql")

        print("\nEnd !")

    # elif args.command == 'package':
    #     basename = basename_from_project(args.QGS_PROJECT)
    #     files = project_related_files(basename)
    #
    #     with ZipFile(f'media/{basename}.zip', 'w') as zip_file:
    #         for file in files:
    #             print(file)
    #             zip_file.write(file)


if __name__ == "__main__":
    exit(main())
