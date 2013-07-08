use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_signature_decode {
    my ($content, $expects) = @_;
    my $sig = WWW::YouTube::Download::_getsig($content);
    is $sig, $expects;
}

# 43
test_signature_decode(
    '5AEEAE0EC39677BC65FD9021CCD115F1F2DBD5A59E4.C0B243A3E2DED6769199AF3461781E75122AE135135',
    '931EA22157E1871643FA9519676DED253A342B0C.4E95A5DBD2F1F511DCC1209DF56CB77693CE0EAE',
);

# 88
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[]}|:;?/>.<',
    'J:|}][{=+-_)(*&;%$#@>MNBVCXZASDFGH^KLPOIUYTREWQ0987654321mnbvcxzasdfghrklpoiuytej',
);

# 87 
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$^&*()_-+={[]}|:;?/>.<',
    '!?;:|}][{=+-_)(*&^$#@/MNBVCXZASqFGHJKLPOIUYTREWQ0987654321mnbvcxzasdfghjklpoiuytr',
);

# 86
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[|};?/>.<',
    'ertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!/#$%^&*()_-+={[|};?@',
);

# 85
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[};?/>.<',
    '{>/?;}[.=+-_)(*&^%$#@!MqBVCXZASDFwHJKLPOIUYTREWQ0987654321mnbvcxzasdfghjklpoiuytr',
);

# 84
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[};?>.<',
    '<.>?;}[{=+-_)(*&^%$#@!MNBVCXZASDFGHJKLPOIUYTREWe098765432rmnbvcxzasdfghjklpoiuyt1',
);
 
# 83
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!#$%^&*()_+={[};?/>.<',
    'D.>/?;}[{=+_)(*&^%$#!MNBVCXeAS<FGHJKLPOIUYTREWZ0987654321mnbvcxzasdfghjklpoiuytrQ',
);

# 82
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKHGFDSAZXCVBNM!@#$%^&*(-+={[};?/>.<',
    'Q>/?;}[{=+-(*<^%$#@!MNBVCXZASDFGHKLPOIUY8REWT0q&7654321mnbvcxzasdfghjklpoiuytrew9',
);

done_testing;
