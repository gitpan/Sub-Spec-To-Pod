package Sub::Spec::To::Pod;

use 5.010;
use strict;
use warnings;
use Log::Any '$log';

use Data::Sah;
use Lingua::EN::Numbers::Ordinate;

require Exporter;
our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(spec_to_pod gen_module_subs_pod);

our $VERSION = '0.21'; # VERSION

our %SPEC;

sub _parse_schema {
    Data::Sah::normalize_schema($_[0]);
}

$SPEC{spec_to_pod} = {
    summary => 'Generate POD documentation from sub spec',
    args => {
        spec => ['hash*' => {}],
    },
    result_naked => 1,
};
sub spec_to_pod($;$) {
    # to minimize startup overhead
    require Data::Dump;
    require Data::Dump::Partial;
    require List::MoreUtils;
    require Sub::Spec::Util;

    my %args = @_;
    my $sub_spec = $args{spec} or return [400, "Please specify spec"];
    $log->trace("-> spec_to_pod($sub_spec->{_package}::$sub_spec->{name})");

    my $pod = "";

    die "No name in spec" unless $sub_spec->{name};
    $log->trace("Generating POD for $sub_spec->{name} ...");

    my $naked = $sub_spec->{result_naked};

    my $pres = Sub::Spec::Util::parse_args_as($sub_spec->{args_as}//"hash");
    my $args_var = $pres->{args_var};
    $pod .= "=head2 $sub_spec->{name}($args_var) -> ".
        ($naked ? "RESULT" : "[STATUS_CODE, ERR_MSG, RESULT]")."\n\n";

    if ($sub_spec->{summary}) {
        $pod .= "$sub_spec->{summary}.\n\n";
    }

    my $desc = $sub_spec->{description};
    if ($desc) {
        $desc =~ s/^\n+//; $desc =~ s/\n+$//;
        $pod .= "$desc\n\n";
    }

    if ($naked) {

    } else {
        $pod .= <<'_';
Returns a 3-element arrayref. STATUS_CODE is 200 on success, or an error code
between 3xx-5xx (just like in HTTP). ERR_MSG is a string containing error
message, RESULT is the actual result.

_
    }

    my $features = $sub_spec->{features} // {};
    if ($features->{reverse}) {
        $pod .= <<'_';
This function supports reverse operation. To reverse, add argument C<-reverse>
=> 1.

_
    }
    if ($features->{undo}) {
        $pod .= <<'_';
This function supports undo operation. See L<Sub::Spec::Clause::features> for
details on how to perform do/undo/redo.

_
    }
    if ($features->{dry_run}) {
        $pod .= <<'_';
This function supports dry-run (simulation) mode. To run in dry-run mode, add
argument C<-dry_run> => 1.

_
    }
    if ($features->{pure}) {
        $pod .= <<'_';
This function is declared as pure, meaning it does not change any external state
or have any side effects.

_
    }

    my $args  = $sub_spec->{args} // {};
    $args = { map {$_ => _parse_schema($args->{$_})} keys %$args };
    my $has_cat = grep { $_->{clause_sets}[0]{arg_category} }
        values %$args;

    if (scalar keys %$args) {
        my $noted_star_req;
        my $prev_cat;
        for my $name (sort {
            (($args->{$a}{clause_sets}[0]{arg_category} // "") cmp
                 ($args->{$b}{clause_sets}[0]{arg_category} // "")) ||
                     (($args->{$a}{clause_sets}[0]{arg_pos} // 9999) <=>
                          ($args->{$b}{clause_sets}[0]{arg_pos} // 9999)) ||
                              ($a cmp $b) } keys %$args) {
            my $arg = $args->{$name};
            my $ah0 = $arg->{clause_sets}[0];

            my $cat = $ah0->{arg_category} // "";
            if (!defined($prev_cat) || $prev_cat ne $cat) {
                $pod .= "=back\n\n" if defined($prev_cat);
                $pod .= ($cat ? ucfirst("$cat arguments") :
                             ($has_cat ? "General arguments":"Arguments"));
                $pod .= " (C<*> denotes required arguments)"
                    unless $noted_star_req++;
                $pod .= ":\n\n=over 4\n\n";
                $prev_cat = $cat;
            }

            $pod .= "=item * B<$name>".($ah0->{req} ? "*" : "")." => ";
            my $type;
            if ($arg->{type} eq 'any') {
                my @schemas = map {_parse_schema($_)} @{$ah0->{of}};
                my @types   = map {$_->{type}} @schemas;
                @types      = sort List::MoreUtils::uniq(@types);
                $type       = join("|", @types);
            } else {
                $type       = $arg->{type};
            }
            $pod .= "I<$type>";
            $pod .= " (default ".
                (defined($ah0->{default}) ?
                     "C<".Data::Dump::Partial::dumpp($ah0->{default}).">"
                         : "none").
                             ")"
                               if defined($ah0->{default});
            $pod .= "\n\n";

            my $args_as = $sub_spec->{args_as} // 'hash';
            if ($args_as =~ /array/) {
                my $pos = $ah0->{arg_pos};
                my $greedy = $ah0->{arg_greedy};
                if (defined $pos) {
                    $pod .= ordinate($pos+1).
                        ($greedy ? " to the last argument(s)" : " argument");
                    if ($args_as =~ /ref/) {
                        if ($greedy) {
                            $pod .= " (\@{\$args}[$pos..last])";
                        } else {
                            $pod .= " (\$args->[$pos])";
                        }
                    } else {
                        if ($greedy) {
                            $pod .= " (\@args[$pos..last])";
                        } else {
                            $pod .= " (\$args[$pos])";
                        }
                    }
                    $pod .= ".\n\n";
                }
            }

            my $aliases = $ah0->{arg_aliases};
            if ($aliases && keys %$aliases) {
                $pod .= "Aliases: ";
                my $i = 0;
                for my $al (sort keys %$aliases) {
                    $pod .= ", " if $i++;
                    my $alinfo = $aliases->{$al};
                    $pod .= "B<$al>".
                        ($alinfo->{summary} ? " ($alinfo->{summary})" : "");
                }
                $pod .= ".\n\n";
            }

            $pod .= "Value must be one of:\n\n".
                join("", map {" $_\n"} split /\n/,
                     Data::Dump::dump($ah0->{in}))."\n\n"
                           if defined($ah0->{in});

            #my $o = $ah0->{arg_pos};
            #my $g = $ah0->{arg_greedy};

            $pod .= "$ah0->{summary}.\n\n" if $ah0->{summary};

            my $desc = $ah0->{description};
            if ($desc) {
                $desc =~ s/^\n+//; $desc =~ s/\n+$//;
                # XXX format/rewrap
                $pod .= "$desc\n\n";
            }
        }
        $pod .= "=back\n\n";

    } else {

        $pod .= "No known arguments at this time.\n\n";

    }

    $log->trace("<- spec_to_usage()");
    $pod;
}

$SPEC{gen_module_subs_pod} = {
    summary => '',
    args => {
        module => ['str*' => {}],
        specs => ['hash' => {}],
        load => ['bool' => {
            summary => 'Whether to load module using "require"',
            default => 1,
        }],
        path => ['str' => {
            summary => 'Specify exact path to load module '.
                '(instead of relying on @INC)',
        }],
    },
    result_naked => 1,
};
sub gen_module_subs_pod {
    my %args = @_;
    my $module = $args{module} or return [400, "Please specify module"];
    my $specs  = $args{specs};

    # require module and get specs
    my $modulep = $args{path};
    if (!defined($modulep)) {
        $modulep = $module;
        $modulep =~ s!::!/!g; $modulep .= ".pm";
    }
    if (!$specs) {
        if ($args{load} // 1) {
            $log->trace("Attempting to load $modulep ...");
            eval { require $modulep };
            die $@ if $@;
        }
        no strict 'refs';
        $specs = \%{$module."::SPEC"};
        #$log->tracef("\%$module\::SPEC = %s", $specs);
        die "Can't find \%SPEC in package $module\n" unless $specs;
    }
    $log->tracef("Functions that have spec: %s", [keys %$specs]);
    for (keys %$specs) {
        $specs->{$_}{_package} //= $module;
        $specs->{$_}{name}     //= $_;
    }

    join("", map { spec_to_pod(spec=>$specs->{$_}) } sort keys %$specs);
}

1;
# ABSTRACT: Generate POD documentation from sub spec


=pod

=head1 NAME

Sub::Spec::To::Pod - Generate POD documentation from sub spec

=head1 VERSION

version 0.21

=head1 SYNOPSIS

 % perl -MSub::Spec::To::Pod=gen_module_subs_pod \
     -e'print gen_module_subs_pod(module=>"MyModule")'

=head1 DESCRIPTION

B<NOTICE>: This module and the L<Sub::Spec> standard is deprecated as of Jan
2012. L<Rinci> is the new specification to replace Sub::Spec, it is about 95%
compatible with Sub::Spec, but corrects a few issues and is more generic.
L<Rias> is the Perl implementation for Rinci and many of its modules can handle
existing Sub::Spec sub specs. L<Rias::Sub::To::POD> is the replacement for
Sub::Spec::To::Pod.

This module generates API POD documentation from sub specs in a specified
module. Example specification:

 our %SPEC;

 $SPEC{sub1} = {
     summary     => 'Summary of sub1.',
     description => "Description of sub1 ...",
     args        => {
         arg1 => ['int*' => {
             summary => 'Blah ...',
             default => 0,
         }],
         arg2 => [str => {
             summary => 'Blah blah ...',
             ...
         }
     },
 }
 sub sub1 { ... }

 $SPEC{sub2} = { ... };
 sub sub2 { ... }

Example output:

 =head2 sub1(%args) -> [STATUS_CODE, ERR_MSG, RESULT]

 Summary of sub1.

 Description of sub1...

 Arguments (* denotes required arguments):

 =over 4

 =item * arg1* => INT (default 0)

 Blah ...

 =item * arg2 => STR (default none)

 Blah blah ...

 =back

 =head2 sub2(%args) -> [STATUS_CODE, ERR_MSG, RESULT]

 ...

This module uses L<Log::Any> logging framework.

=head1 FUNCTIONS

None of the functions are exported by default, but they are exportable.

=head2 gen_module_subs_pod(%args) -> RESULT


Arguments (C<*> denotes required arguments):

=over 4

=item * B<load> => I<bool> (default C<1>)

Whether to load module using "require".

=item * B<module>* => I<str>

=item * B<path> => I<str>

Specify exact path to load module (instead of relying on @INC).

=item * B<specs> => I<hash>

=back

=head2 spec_to_pod(%args) -> RESULT


Generate POD documentation from sub spec.

Arguments (C<*> denotes required arguments):

=over 4

=item * B<spec>* => I<hash>

=back

=head1 SEE ALSO

L<Sub::Spec>

L<Sub::Spec::To::HTML>

L<Sub::Spec::To::Org>

L<Sub::Spec::To::Text>

=head1 AUTHOR

Steven Haryanto <stevenharyanto@gmail.com>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2012 by Steven Haryanto.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

