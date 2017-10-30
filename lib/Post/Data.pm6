use v6.c;

use JSON::Fast;
unit class Post::Data:ver<0.0.1>;

=begin pod

=head1 NAME

Post::Data - blah blah blah

=head1 SYNOPSIS

  use Post::Data;

=head1 DESCRIPTION

Post::Data is ...

=head1 AUTHOR

wbiker <wbiker@gmx.at>

=head1 COPYRIGHT AND LICENSE

Copyright 2017 wbiker

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

has $.url;
has $.index;
has $.exitcode;
has $.output;

method post(:%data, :$type) {
    my $json = to-json %data, :!pretty;
    "tmp.json".IO.spurt($json);
    #dd $json;
    my $url = $!url ~ "/" ~ $!index ~ "/" ~ $type;

    "tmp.json".IO.spurt($json);
    my @cmds = "curl", "-XPOST", "-H", "content-type:application/json", $url, "-d", '@tmp.json';
    my $proc = shell @cmds, :out;

    $!exitcode = $proc.exitcode;
    $!output = $proc.out.slurp;
}
