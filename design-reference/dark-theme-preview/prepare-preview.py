"""Prepare the archived, approved v2 study without modifying current sources."""

from pathlib import Path
import shlex
import subprocess
import tempfile


BASE_COMMIT = 'a21a7a5a16acad4a08364f1d59e34fbbc771d882'
ARCHIVE_PATHS = (
    'Sources', 'Tests', 'scripts', 'fixer.icon', 'ThirdPartyLicenses',
    'project.yml', 'Info.plist', 'Fixer.entitlements', 'Package.resolved',
    'THIRD_PARTY_NOTICES.md',
)


def main():
    repo = Path(__file__).resolve().parents[2]
    reference = repo / 'design-reference/dark-theme-preview'
    runs = repo / '.build/dark-theme-preview-study'
    runs.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix='approved-v2-', dir=runs))
    study = run / 'project'
    renders = run / 'renders'
    study.mkdir()
    renders.mkdir()

    # Read the original source directly from its pinned commit. Copying the
    # working tree would mix the archived proposal with today's production theme.
    archive = subprocess.run(
        ['git', 'archive', '--format=tar', BASE_COMMIT, *ARCHIVE_PATHS],
        cwd=repo, check=True, stdout=subprocess.PIPE,
    )
    subprocess.run(
        ['tar', '-xf', '-', '-C', str(study)],
        input=archive.stdout, check=True,
    )

    # The retained patch is the approved v2 recipe. It is read only; all patched
    # files and any later renders stay in this newly created study directory.
    subprocess.run(
        ['patch', '--batch', '--forward', '-p1', '-i', str(reference / 'prototype.patch')],
        cwd=study, check=True,
    )

    print(f'Base commit: {BASE_COMMIT}')
    print(f'Project: {study}')
    print(f'Renders: {renders}')
    print('\nTo render the archived proposal, run:')
    print(shlex.join([str(study / 'scripts/generate-project.sh')]))
    print(shlex.join([
        'xcodebuild', '-project', str(study / 'Fixer.xcodeproj'),
        '-scheme', 'Fixer', '-configuration', 'Debug',
        '-destination', 'platform=macOS',
        '-derivedDataPath', str(run / 'DerivedData'),
        '-only-testing:FixerTests/V2PreviewRenderingTests/rendersDarkWorkspaceExample()',
        f'FIXER_PREVIEW_DIR={renders}', 'test',
    ]))


if __name__ == '__main__':
    main()
