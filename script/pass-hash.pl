use 5.038;
use Crypt::Eksblowfish::Bcrypt qw(bcrypt_hash);
use Encode qw(is_utf8 encode_utf8);

my $plain_text = 'passport';
if ( is_utf8($plain_text) ) {
      #  Bcrypt expects octets
      $plain_text = encode_utf8($plain_text);
}
say "plain text: $plain_text";
my $nul = 0;
my $cost = 8;
$nul = $nul ? 'a' : '';
$cost = sprintf("%02i", 0+$cost);
say "nul: $nul";
say "cost: $cost";
my $settings_base = join('','$2',$nul,'$',$cost, '$');
say "settings base: $settings_base";
my $salt = join('', map { chr(int(rand(256))) } 1 .. 16);
$salt = Crypt::Eksblowfish::Bcrypt::en_base64( $salt );
say "salt: $salt";
$salt = 'SfDfgB1T8ZMctl83OAUzne';
say "salt: $salt";
my $settings_str =  $settings_base.$salt;
my $hash = Crypt::Eksblowfish::Bcrypt::bcrypt($plain_text, $settings_str);
say $hash;
