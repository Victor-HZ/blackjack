#!/usr/bin/env python3
"""Generate a deterministic native Xcode project using only the Python standard library.

Source of truth: this script, Config/*.xcconfig, and files under BlackjackStudio/
and BlackjackStudioUITests/. Run again whenever Swift files are added or removed.
No third-party project generator or remote Swift package resolution is required.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import xml.etree.ElementTree as ET

IOS = Path(__file__).resolve().parents[1]
PROJECT = IOS / 'BlackjackStudio.xcodeproj'
OBJECTS: dict[str, dict] = {}


def identifier(name: str) -> str:
    return hashlib.sha256(('blackjack-studio:' + name).encode()).hexdigest()[:24].upper()


def add(object_name: str, isa: str, **fields) -> str:
    key = identifier(object_name)
    if key in OBJECTS:
        raise ValueError(f'duplicate project object: {object_name}')
    OBJECTS[key] = {'isa': isa, **fields}
    return key


def serialize(value, level=0) -> str:
    indent = '\t' * level
    if isinstance(value, dict):
        entries = [f'{indent}\t{serialize(str(key))} = {serialize(item, level + 1)};' for key, item in value.items()]
        return '{\n' + '\n'.join(entries) + '\n' + indent + '}'
    if isinstance(value, (tuple, list)):
        if not value:
            return '()'
        return '(\n' + '\n'.join(f'{indent}\t{serialize(item, level + 1)},' for item in value) + '\n' + indent + ')'
    if isinstance(value, int):
        return str(value)
    return json.dumps(str(value), ensure_ascii=False)


def file_ref(relative: str, file_type: str, source_tree='<group>', **fields) -> str:
    return add('file:' + relative, 'PBXFileReference', lastKnownFileType=file_type,
               path=relative, sourceTree=source_tree, **fields)


def build_file(reference: str, phase: str, package=False) -> str:
    return add('build:' + phase + ':' + reference, 'PBXBuildFile', **({'productRef': reference} if package else {'fileRef': reference}))


def source_group(directory: str, sources: list[Path], special: dict[str, str] | None = None) -> tuple[str, dict[str, str]]:
    """Build groups using repository-relative file paths with SOURCE_ROOT refs."""
    special = special or {}
    refs: dict[str, str] = {}
    tree: dict = {}
    file_map = {path.relative_to(IOS / directory).as_posix(): 'sourcecode.swift' for path in sources}
    file_map.update(special)
    for relative, file_type in sorted(file_map.items()):
        parts = relative.split('/')
        branch = tree
        for part in parts[:-1]:
            branch = branch.setdefault(part, {})
        full_path = f'{directory}/{relative}'
        reference = file_ref(full_path, file_type, source_tree='SOURCE_ROOT', name=parts[-1])
        refs[relative] = reference
        branch[parts[-1]] = reference

    def group(branch: dict, path: str, title: str) -> str:
        children = [group(item, f'{path}/{name}', name) if isinstance(item, dict) else item for name, item in sorted(branch.items())]
        return add('group:' + path, 'PBXGroup', children=children, name=title, sourceTree='<group>')

    return group(tree, directory, directory), refs


def target_configs(target_name: str, settings: dict, config_refs: dict[str, str]) -> str:
    configs = []
    for configuration in ['Debug', 'Release']:
        configs.append(add(f'config:{target_name}:{configuration}', 'XCBuildConfiguration',
                           baseConfigurationReference=config_refs[configuration], buildSettings=settings, name=configuration))
    return add('config-list:' + target_name, 'XCConfigurationList', buildConfigurations=configs,
               defaultConfigurationIsVisible=0, defaultConfigurationName='Release')


def buildable(parent: ET.Element, target_name: str, extension: str) -> None:
    ET.SubElement(parent, 'BuildableReference', {
        'BuildableIdentifier':'primary', 'BlueprintIdentifier':identifier('target:' + target_name),
        'BuildableName':target_name + extension, 'BlueprintName':target_name,
        'ReferencedContainer':'container:BlackjackStudio.xcodeproj',
    })


def scheme(test_names: list[str], release=False) -> str:
    root = ET.Element('Scheme', {'LastUpgradeVersion':'1600','version':'1.7'})
    build_action = ET.SubElement(root, 'BuildAction', {'parallelizeBuildables':'YES','buildImplicitDependencies':'YES'})
    entries = ET.SubElement(build_action, 'BuildActionEntries')
    app = ET.SubElement(entries, 'BuildActionEntry', {'buildForTesting':'YES','buildForRunning':'YES','buildForProfiling':'YES','buildForArchiving':'YES','buildForAnalyzing':'YES'})
    buildable(app, 'BlackjackStudio', '.app')
    for name in test_names:
        item = ET.SubElement(entries, 'BuildActionEntry', {'buildForTesting':'YES','buildForRunning':'NO','buildForProfiling':'NO','buildForArchiving':'NO','buildForAnalyzing':'YES'})
        buildable(item, name, '.xctest')
    test_action = ET.SubElement(root, 'TestAction', {'buildConfiguration':'Debug','selectedDebuggerIdentifier':'Xcode.DebuggerFoundation.Debugger.LLDB','selectedLauncherIdentifier':'Xcode.IDEFoundation.Launcher.LLDB','shouldUseLaunchSchemeArgsEnv':'YES'})
    testables = ET.SubElement(test_action, 'Testables')
    for name in test_names:
        testable = ET.SubElement(testables, 'TestableReference', {'skipped':'NO','parallelizable':'NO'})
        buildable(testable, name, '.xctest')
    macro = ET.SubElement(test_action, 'MacroExpansion')
    buildable(macro, 'BlackjackStudio', '.app')
    launch = ET.SubElement(root, 'LaunchAction', {'buildConfiguration':'Release' if release else 'Debug','selectedDebuggerIdentifier':'Xcode.DebuggerFoundation.Debugger.LLDB','selectedLauncherIdentifier':'Xcode.IDEFoundation.Launcher.LLDB','launchStyle':'0','useCustomWorkingDirectory':'NO','ignoresPersistentStateOnLaunch':'NO','debugDocumentVersioning':'YES','debugServiceExtension':'internal','allowLocationSimulation':'YES'})
    runnable = ET.SubElement(launch, 'BuildableProductRunnable', {'runnableDebuggingMode':'0'})
    buildable(runnable, 'BlackjackStudio', '.app')
    if not release:
        ET.SubElement(launch, 'StoreKitConfigurationFileReference', {'identifier':'../../BlackjackStudio/Resources/BlackjackStudio.storekit'})
    profile = ET.SubElement(root, 'ProfileAction', {'buildConfiguration':'Release','shouldUseLaunchSchemeArgsEnv':'YES','savedToolIdentifier':'','useCustomWorkingDirectory':'NO','debugDocumentVersioning':'YES'})
    buildable(ET.SubElement(profile, 'BuildableProductRunnable', {'runnableDebuggingMode':'0'}), 'BlackjackStudio', '.app')
    ET.SubElement(root, 'AnalyzeAction', {'buildConfiguration':'Debug'})
    ET.SubElement(root, 'ArchiveAction', {'buildConfiguration':'Release','revealArchiveInOrganizer':'YES'})
    ET.indent(root, space='   ')
    return '<?xml version="1.0" encoding="UTF-8"?>\n' + ET.tostring(root, encoding='unicode') + '\n'


def generate() -> dict[Path, str]:
    app_sources = sorted((IOS / 'BlackjackStudio').rglob('*.swift'))
    if not app_sources:
        raise RuntimeError('No app Swift sources were found.')
    app_group, app_refs = source_group('BlackjackStudio', app_sources, {
        'Resources/Assets.xcassets':'folder.assetcatalog',
        'Resources/Info.plist':'text.plist.xml',
        'Resources/PrivacyInfo.xcprivacy':'text.xml',
        'Resources/BlackjackStudio.storekit':'text',
    })
    config_refs = {name:file_ref(f'Config/{name}.xcconfig', 'text.xcconfig', source_tree='SOURCE_ROOT', name=name + '.xcconfig') for name in ['Base','Debug','Release','Publisher']}
    config_group = add('group:Config','PBXGroup',children=list(config_refs.values()),name='Config',sourceTree='<group>')
    package_refs, package_products, package_files = [], [], []
    for name in ['BlackjackCore','TrainingCore','StudioCore']:
        if not (IOS / 'Packages' / name / 'Package.swift').is_file():
            raise RuntimeError(f'Missing local package: {name}')
        reference = add('package:' + name, 'XCLocalSwiftPackageReference', relativePath='Packages/' + name)
        package_refs.append(reference)
        package_products.append(add('package-product:' + name, 'XCSwiftPackageProductDependency', package=reference, productName=name))
        package_files.append(file_ref('Packages/' + name, 'folder', source_tree='SOURCE_ROOT', name=name))
    packages_group = add('group:Packages','PBXGroup',children=package_files,name='Packages',sourceTree='<group>')
    app_product = add('product:BlackjackStudio','PBXFileReference',explicitFileType='wrapper.application',includeInIndex=0,path='BlackjackStudio.app',sourceTree='BUILT_PRODUCTS_DIR')
    product_refs = [app_product]
    source_phase = add('phase:app:sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[build_file(app_refs[p.relative_to(IOS / 'BlackjackStudio').as_posix()], 'app-sources') for p in app_sources],runOnlyForDeploymentPostprocessing=0)
    framework_phase = add('phase:app:frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[build_file(p,'app-frameworks',package=True) for p in package_products],runOnlyForDeploymentPostprocessing=0)
    resource_phase = add('phase:app:resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=[build_file(app_refs[name],'app-resources') for name in ['Resources/Assets.xcassets','Resources/PrivacyInfo.xcprivacy']],runOnlyForDeploymentPostprocessing=0)
    app_settings = {'PRODUCT_NAME':'$(TARGET_NAME)','INFOPLIST_FILE':'BlackjackStudio/Resources/Info.plist','GENERATE_INFOPLIST_FILE':'NO','ASSETCATALOG_COMPILER_APPICON_NAME':'AppIcon'}
    app_target = add('target:BlackjackStudio','PBXNativeTarget',buildConfigurationList=target_configs('BlackjackStudio',app_settings,config_refs),buildPhases=[source_phase,framework_phase,resource_phase],buildRules=[],dependencies=[],name='BlackjackStudio',packageProductDependencies=package_products,productName='BlackjackStudio',productReference=app_product,productType='com.apple.product-type.application')
    targets = [app_target]
    test_groups, test_names = [], []
    for name, ui_test in [('BlackjackStudioUITests',True),('BlackjackStudioTests',False)]:
        sources = sorted((IOS / name).rglob('*.swift')) if (IOS / name).exists() else []
        if not ui_test and not sources:
            continue
        test_names.append(name)
        group, refs = source_group(name,sources)
        test_groups.append(group)
        product = add('product:' + name,'PBXFileReference',explicitFileType='wrapper.cfbundle',includeInIndex=0,path=name + '.xctest',sourceTree='BUILT_PRODUCTS_DIR')
        product_refs.append(product)
        sources_phase = add('phase:' + name + ':sources','PBXSourcesBuildPhase',buildActionMask=2147483647,files=[build_file(ref,name + '-sources') for ref in refs.values()],runOnlyForDeploymentPostprocessing=0)
        test_products = [] if ui_test else package_products
        frameworks = add('phase:' + name + ':frameworks','PBXFrameworksBuildPhase',buildActionMask=2147483647,files=[build_file(product, name + '-frameworks', package=True) for product in test_products],runOnlyForDeploymentPostprocessing=0)
        test_resources = [build_file(app_refs['Resources/BlackjackStudio.storekit'], name + '-resources')] if ui_test else []
        resources = add('phase:' + name + ':resources','PBXResourcesBuildPhase',buildActionMask=2147483647,files=test_resources,runOnlyForDeploymentPostprocessing=0)
        proxy = add('proxy:' + name,'PBXContainerItemProxy',containerPortal=identifier('project'),proxyType=1,remoteGlobalIDString=app_target,remoteInfo='BlackjackStudio')
        dependency = add('dependency:' + name,'PBXTargetDependency',target=app_target,targetProxy=proxy)
        settings = {'PRODUCT_NAME':'$(TARGET_NAME)','PRODUCT_BUNDLE_IDENTIFIER':'$(STUDIO_BUNDLE_IDENTIFIER).' + ('uitests' if ui_test else 'tests'),'GENERATE_INFOPLIST_FILE':'YES','TEST_TARGET_NAME':'BlackjackStudio','SWIFT_EMIT_LOC_STRINGS':'NO'}
        if not ui_test:
            settings.update({'TEST_HOST':'$(BUILT_PRODUCTS_DIR)/BlackjackStudio.app/BlackjackStudio','BUNDLE_LOADER':'$(TEST_HOST)'})
        targets.append(add('target:' + name,'PBXNativeTarget',buildConfigurationList=target_configs(name,settings,config_refs),buildPhases=[sources_phase,frameworks,resources],buildRules=[],dependencies=[dependency],name=name,packageProductDependencies=test_products,productName=name,productReference=product,productType='com.apple.product-type.bundle.ui-testing' if ui_test else 'com.apple.product-type.bundle.unit-test'))
    products_group = add('group:Products','PBXGroup',children=product_refs,name='Products',sourceTree='<group>')
    main_group = add('group:root','PBXGroup',children=[app_group,*test_groups,packages_group,config_group,products_group],sourceTree='<group>')
    target_attributes = {app_target:{'CreatedOnToolsVersion':'16.0','SystemCapabilities':{'com.apple.InAppPurchase':{'enabled':1}}}}
    for name in test_names:
        target_attributes[identifier('target:' + name)] = {'CreatedOnToolsVersion':'16.0','TestTargetID':app_target}
    add('project','PBXProject',attributes={'BuildIndependentTargetsInParallel':'YES','LastUpgradeCheck':'1600','TargetAttributes':target_attributes},buildConfigurationList=target_configs('project',{},config_refs),compatibilityVersion='Xcode 14.0',developmentRegion='en',hasScannedForEncodings=0,knownRegions=['en','Base'],mainGroup=main_group,packageReferences=package_refs,productRefGroup=products_group,projectDirPath='',projectRoot='',targets=targets)
    structure = {'archiveVersion':1,'classes':{},'objectVersion':56,'objects':dict(sorted(OBJECTS.items(),key=lambda item:(item[1]['isa'],item[0]))),'rootObject':identifier('project')}
    outputs = {PROJECT / 'project.pbxproj':'// !$*UTF8*$!\n' + serialize(structure) + '\n'}
    outputs[PROJECT / 'xcshareddata/xcschemes/BlackjackStudio.xcscheme'] = scheme(test_names)
    outputs[PROJECT / 'xcshareddata/xcschemes/BlackjackStudio Release.xcscheme'] = scheme(test_names,release=True)
    outputs[PROJECT / 'project.xcworkspace/contents.xcworkspacedata'] = '<?xml version="1.0" encoding="UTF-8"?>\n<Workspace version="1.0"><FileRef location="self:"></FileRef></Workspace>\n'
    print(f'Discovered {len(app_sources)} app Swift files, {len(test_names)} test targets, and 3 local packages.')
    return outputs


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check',action='store_true',help='Fail if generated project files differ; write nothing.')
    args = parser.parse_args()
    outputs = generate()
    changed = []
    for path,text in outputs.items():
        if path.exists() and path.read_text() == text:
            continue
        changed.append(str(path.relative_to(IOS)))
        if not args.check:
            path.parent.mkdir(parents=True,exist_ok=True)
            path.write_text(text)
    if args.check and changed:
        print('Project is stale. Run ios/scripts/generate-xcode-project.py:\n' + '\n'.join(changed),file=sys.stderr)
        return 1
    print('Xcode project is current.' if args.check else f'Generated {len(outputs)} project/scheme files ({len(changed)} changed).')
    return 0


if __name__ == '__main__':
    sys.exit(main())
