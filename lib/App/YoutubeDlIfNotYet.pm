package App::YoutubeDlIfNotYet;

# AUTHORITY
# DATE
# DIST
# VERSION

use 5.010001;
use strict;
use warnings;

use Filename::Audio;
use Filename::Video;
use Regexp::Pattern::YouTube;

our %SPEC;

sub _search_id_in_log_file {
    my ($id, $path) = @_;

    my $re = "-($Regexp::Pattern::YouTube::RE{video_id}{pat})\\.(?:$Filename::Audio::STR_RE|$Filename::Video::STR_RE)(?:\\t|\\z)";
    $re = qr/$re/;

    state $cache = do {
        my %mem;
        open my($fh), "<", $path or die "Can't open log file '$path': $!";
        while (my $line = <$fh>) {
            chomp $line;
            if ($line =~ $re) {
                next if $mem{$1};
                $mem{$1} = $line;
            }
        }
        \%mem;
    };

    $cache->{$id};
}

$SPEC{youtube_dl_if_not_yet} = {
    v => 1.1,
    summary => 'Download videos using youtube-dl only if videos have not been donwnloaded yet',
    description => <<'_',

This is a wrapper for **youtube-dl**; it tries to extract downloaded video ID's
from filenames or URL's or video ID's listed in a text file, e.g.:

    35682594        Table Tennis Shots- If Were Not Filmed, Nobody Would Believe [HD]-dUjxqFbWzQo.mp4       date:[2019-12-29 ]

or:

    https://www.youtube.com/embed/U9v2S49sHeQ?rel=0

or:

    U9v2S49sHeQ

When a video ID is found then it is assumed to be already downloaded in the past
and will not be downloaded again.

_
    args => {
        urls_or_ids => {
            'x.name.is_plural' => 1,
            'x.name.singular' => 'url_or_id',
            schema => ['array*', of=>'str*', min_len=>1],
            req => 1,
            pos => 0,
            greedy => 1,
        },
        log_file => {
            summary => 'File that contains list of download filenames',
            schema => 'str*', # XXX filename
            default => do {
                my $path;
                my @paths = (
                    "$ENV{HOME}/notes/download-logs.org",
                    "$ENV{HOME}/download-logs.org",
                );
                for my $p (@paths) {
                    if (-f $p) {
                        $path = $p; last;
                    }
                }
                die "Cannot find download log file, please specify using ".
                    "--log-file or put the log file in one of: ".
                    (join ", ", @paths) unless $path;
                $path;
            },
        },
    },
    deps => {
        prog => 'youtube-dl',
    },
};
sub youtube_dl_if_not_yet {
    my %args = @_;

    my @argv_for_youtube_dl;
    for my $arg (@{$args{urls_or_ids}}) {
        if ($arg =~ /\A$re_video_id\z/) {
            if (my $filename = _search_id_in_log_file($arg, $args{log_file})) {
                log_info "Video ID %s (%s) has been downloaded, skipped", $arg, $filename;
                next;
            }
        } elsif ($arg =~ m!\Ahttps?://(?:www\.)youtube\.com.+?v=($re_video_id)!i) {
            my $id = $1;
            if (my $filename = _search_id_in_log_file($id, $args{log_file})) {
                log_info "Video ID %s (%s) has been downloaded, skipped", $id, $filename;
                next;
            }
        }
        push @argv_for_youtube_dl, $arg;
    }

    system({log=>1, die=>1}, "youtube-dl", @argv_for_youtube_dl);
    [200];
}

1;
# ABSTRACT: Download

=head1 DESCRIPTION

This distribution provides the following command-line utilities related to
YouTube:

#INSERT_EXECS_LIST


=head1 SEE ALSO

L<youtube-dl-if-not-yet> from L<App::YoutubeDlIfNotYet>

=cut
