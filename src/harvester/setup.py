# -*- coding: utf-8 -*-
from setuptools import setup

install_requires = open('requirements.txt').read().split('\n')

setup(
    name='harvester',
    version='0.0.1',
    description='OPERANDI - Harvester',
    long_description=open('README.md').read(),
    long_description_content_type='text/markdown',
    author='Mehmed Mustafa',
    author_email='mehmed.mustafa@gwdg.de',
    url='https://github.com/MehmedGIT/OPERANDI_TestRepo',
    license='Apache License 2.0',
    packages=['harvester', 'harvester.cli'],
    install_requires=install_requires,
    include_package_data=True,
    package_data={'': ['*.txt']},
    entry_points={
        'console_scripts': [
            'operandi-harvester=harvester.cli:har_cli',
        ]
    },
)
