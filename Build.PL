
use strict;
use warnings;

use Module::Build 0.3601;


my %module_build_args = (
  'build_requires' => {
    'Module::Build' => '0.3601'
  },
  'configure_requires' => {
    'Module::Build' => '0.3601'
  },
  'dist_abstract' => 'Generate POD documentation from sub spec',
  'dist_author' => [
    'Steven Haryanto <stevenharyanto@gmail.com>'
  ],
  'dist_name' => 'Sub-Spec-To-Pod',
  'dist_version' => '0.16',
  'license' => 'perl',
  'module_name' => 'Sub::Spec::To::Pod',
  'recommends' => {},
  'recursive_test_files' => 1,
  'requires' => {
    'Data::Dump::Partial' => '0',
    'JSON' => '0',
    'List::MoreUtils' => '0',
    'Log::Any' => '0',
    'Sub::Spec' => '0.15',
    'perl' => '5.010000'
  },
  'script_files' => []
);


my $build = Module::Build->new(%module_build_args);

$build->create_build_script;
