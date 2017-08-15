#!/usr/bin/env perl
# Notify by Pushover with bulk support
# Bulk: yes
use strict;
use warnings;
use Data::Dumper;
use LWP::UserAgent;

my $ua = LWP::UserAgent->new;
$ua->timeout(10);

my @input;
while (my $l = <STDIN>) {
    push @input, $l;
}

my %global;
my @messages;
my $block;
foreach my $l (@input) {
    chomp $l;
    if ($l) {
        my ($name, $value) = split(/=/, $l, 2);
        if (@messages) {
            $messages[-1]{$name} = $value;
        }
        else {
            $global{$name} = $value;
        }
    }
    else {
        push @messages, {};
    }
}

my $api_key = $global{PARAMETER_1};
die "Missing mandatory parameter for api-key" unless $api_key;

my (%notify);

my @fields = (qw/SHORTDATETIME
                 SERVICESTATE 
                 SERVICEDESC
                 SERVICEOUTPUT
                 HOSTALIAS 
                 HOSTSTATE
                 HOSTOUTPUT
                /);

foreach my $msg (@messages) {
    # collect only the info we're interested in
    # without this, we can't proceed
    my $contact = $msg->{CONTACTPAGER};
    if ($contact) {
        $notify{$contact} ||= {
                               msgs => [],
                               services => {},
                               hosts => {},
                               priority => 0,
                              };
        if ($msg->{SERVICEDESC}) {
            $notify{$contact}{services}{$msg->{SERVICEDESC}}++;
        }
        if ($msg->{HOSTALIAS}) {
            $notify{$contact}{hosts}{$msg->{HOSTALIAS}}++;
        }
        if ($msg->{SERVICESTATE} eq 'CRITICAL') {
            # increase priority if there is a critical state
            $notify{$contact}{priority} = 1,
        }
        foreach my $name (@fields) {
            if ($msg->{$name}) {
                $msg->{$name} =~ s/\x{1}/\n/g;
            }
        }
        my $out = join(" - ", map { $msg->{$_} } grep { $msg->{$_} } @fields);
        push @{$notify{$contact}{msgs}}, $out;
    }
}

print Dumper(\%global);

foreach my $userkey (keys %notify) {
    my $body = join("\n", @{$notify{$userkey}{msgs}});
    my $title = join(" - ", sort keys %{$notify{$userkey}{hosts}}, sort keys %{$notify{$userkey}{services}});
    my $priority = $notify{$userkey}{priority};
    print "Notifying $userkey for $title\n$body\n(priority $priority)\n";
    $ua->post('https://api.pushover.net/1/messages' => {
                                                        token => $api_key,
                                                        user => $userkey,
                                                        title => $title,
                                                        message => $body,
                                                        priority => $priority,
                                                       });
}

