#!/usr/bin/env perl6

use File::Find;

sub MAIN (:$filename, :$output = 'API.md') {

  my @files = $filename ??
      $filename.Array
      !!
      find
        dir => 'lib',
        name => /'.pm6' $/;

  my $apiDocsDir = $*CWD;
  unless $apiDocsDir.add('lib').e {
    say 'Please run this script from the project root directory.';
    exit;
  }

  $apiDocsDir .= add($_) for <docs api>;
  $apiDocsDir.mkdir;

  my @destFiles;
  for @files {
    my $newFile = $apiDocsDir;

    for $*SPEC.splitdir( .relative ).skip(1) {
      $newFile .= add($_);
      $newFile.mkdir unless $newFile.Str.ends-with('.pm6');
    }

    print "Processing { $newFile }...";
    my $docs = qqx{perl6 -Ilib --doc=Markdown $_};

    if $docs.trim {
      my $destFile = $newFile.extension('md');
      $destFile.spurt: $docs;
      @destFiles.push($destFile);
      say "output written to { $destFile.relative }";
    } else {
      say "nothing to output";
    }
  }

  # If processing a single file, do NOT write out the index.
  unless $filename {
    # Write index file
    my $index = "API Pages\n";
    $index ~= '=' x $index.chars.chomp ~ "\n\n";

    for @destFiles {
      # skip(2) == Drop docs/api from path
      my $module-name = $*SPEC.splitdir( .relative ).skip(2).join('::');
      $index ~= "- [{ $module-name }]({ .relative.subst: /".md"$/, "" })\n";
    }

    my $index-page = $apiDocsDir.parent.resolve.add($output);
    $index-page.resolve.spurt: $index;
  }

}
