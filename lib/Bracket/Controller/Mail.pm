package Bracket::Controller::Mail;

use strict;
use warnings;
use base 'Catalyst::Controller';

my $TEST = 0;

=head1 NAME

Bracket::Controller::Mail - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut

=head2 index 

=cut

my $player = '';
my ( $message, $initial_message, $brackets_locked_message,
    $after_round_one_message, $final_4_message, $final_results_message ) = ('','','','','','');
my ( $first_name, $last_name, $player_id ) = ('','','');

sub index : Private {
    my ( $self, $c ) = @_;

    $c->response->body('Matched Bracket::Controller::Mail in Mail.');
}

my @subjects = (
    'Time to Do your Regional Brackets',
    'Time to Choose Final Four Game Winners',
    'Final Bracket Results'
);
my $subject = $subjects[1];

sub do_emailing : Private {
    my ( $self, $c ) = @_;

    my @players = $c->model('DBIC::Player')->all;

    my @addresses;
    foreach my $player (@players) {

        # harrass only active players
        if ( $player->active ) {
            next if ( $TEST && $player->email ne 'hunter@missoula.org' );

#if ( $player->email eq 'hunter@missoula.org' ) {
#if ($player->email eq 'ljh724@hotmail.com') {
#if ($player->email eq 'ejmiller4@charter.net') {
#if ($player->email eq 'hunter@missoula.org' || $player->email eq 'kmn@missoula.org') {
#if ($player->email eq 'mgwal@sbcglobal.net' || $player->email eq 'DavidJWilliford@aol.com') {
#if ($player->email eq 'bhunter21@ivytech.edu' || $player->email eq 'jjhunter1@usieagles.org') {
            push @addresses, $player->email;
            send_email_to( $player, $subject );

            #}
        }
    }

    #	my $address = 'hunter@missoula.org';
    #	send_email_to($address);
    #	$c->stash->{address} = $address;
    $c->stash->{subject}   = $subject;
    $c->stash->{addresses} = \@addresses;
    $c->stash->{template}  = 'initial_email.tt';

}

sub send_email_to {
    my $player  = shift;
    my $subject = shift;

    use Net::SMTP;

    my $smtp_server   = '';
    my $smtp_username = "";
    my $smtp_password = "";
    my $from_name     = 'Bracket Master';
    my $from_email    = 'hunter@missoula.org';
    my $to_email      = $player->email;
    my $message       = make_message($player);
    my $smtp;

    warn "Opening SMTP connection to $smtp_server\n";
    if ( $smtp =
        Net::SMTP->new( $smtp_server, Hello => $smtp_server, Timeout => 60 ) )
    {
        warn "Connected to $smtp_server\n";
    }
    else {
        warn "Could not connect to $smtp_server\n";
        die;
    }
    $smtp->auth( $smtp_username, $smtp_password );

    warn "Sending to $to_email\n";
    $smtp->mail($from_email);
    $smtp->recipient($to_email);
    $smtp->data();
    $smtp->datasend("From: \"$from_name\" <$from_email>\n");
    $smtp->datasend("To: $to_email\n");
    $smtp->datasend("Subject: $subject\n");
    $smtp->datasend("$message\n\n");
    $smtp->dataend();
    sleep 2;

    $smtp->quit;
}

sub make_message {
    my $player = shift;
    $first_name = $player->first_name;
    $last_name  = $player->last_name;
    $player_id  = $player->id;

    $message = <<"END";
Dear NCAA Aficionado $last_name,

It's time to pick your Final Four game winners at:

https://satya.huntana.com/bracket-picks/final4/make/$player_id

The Saturday games are worth 25 points each, and the championship
game is worth 50.  Mathematically speaking, just about everybody still has a 
chance to get in one of the top three spots.  Current standings are at:

https://satya.huntana.com/bracket-picks/all

END

    return $message;
}

$final_results_message = <<"END";
Dear NCAA Bracket Wannabes and Winners,

The deal is done and Bill Hunter has won. He had Kansas all the way.
Final results can be seen at:

https://satya.huntana.com/bracket-picks/all

Two people tied for second so they'll split \$50.

END

$final_4_message = <<"END";
Dear NCAA Aficionado $last_name,

It's time to pick your Final Four game winners at:

https://satya.huntana.com/bracket-picks/final4/make/$player_id

The Saturday games are worth 25 points each, and the championship
game is worth 50.  Mathematically speaking, just about everybody still has a 
chance to get in one of the top three spots.  Current standings are at:

https://satya.huntana.com/bracket-picks/all

END

$after_round_one_message = <<"END";
Dear Bracket Buster $last_name,

The round one points are in.  See the rankings at:

https://satya.huntana.com/bracket-picks/all

END

$initial_message = <<"END";
Dear \$last_name,

Below is the link to your home page to create one NCAA bracket.
In these hard economic times, the bounty has risen slightly over last year.

First  - 60 bucks
Second - 40 greenbacks
Third  - 25 singles 

As last year, there is no entry fee.  It's free as in free beer.

https://satya.huntana.com/bracket-picks/home/\$player->id


NOTES:
* For now, make all your regional picks.  Final 4 game picks will come later.

END

my $original_initial_message = <<"END";
Dear $last_name,

Below is the link to your home page to create one NCAA bracket.
In these hard economic times, the bounty has risen slightly over last year.

First  - 60 bucks
Second - 40 greenbacks
Third  - 25 singles 

As last year, there is no entry fee.  It's free as in free beer.

https://satya.huntana.com/bracket-picks/home/$player->id

If that is not enough to entice you then consider it a favor to test out my
first version of an NCAA bracket application.  It comes with no guarantees 
that you will win or that it will even work.

NOTES:
* For now, make all your regional picks.  Championship game teams and winner
picks will come later.  
* Scoring will (heavily?) favor underdogs.  Each round victory will get 
5 points  times the round number for higher seed and 5 points plus the seed 
then multiplied by the round number.  For example, if your pick a team seeded 
12th to win a round 2 game you will get (5+12)*2 points.  
* The championship game will have a multiplier of 10 (instead of six).
* Scores will probably not be updated very quickly (hey, I do have a day job.)
* You will have to make your championship game picks when that's available
sometime before the final four begins.

Good Luck, and remember be risky.
    
END

$brackets_locked_message = <<"END";
Dear Bracket Buster $last_name,

The NCAA brackets are locked and loaded.  You may see your competition at:

https://satya.huntana.com/bracket-picks/all

END

=head1 AUTHOR

mateu x hunter

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
