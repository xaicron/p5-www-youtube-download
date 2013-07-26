use strict;
use warnings;
use Test::More;
use WWW::YouTube::Download;

sub test_signature_decode {
    my ($content, $expects) = @_;
    my $sig = WWW::YouTube::Download::_getsig($content);
    is $sig, $expects;
}

# 92
test_signature_decode(
    'F9F9B6E6FD47029957AB911A964CC20D95A181A5D37A2DBEFD67D403DB0E8BE4F4910053E4E8A79.0B70B.0B80B8',
    '69B6E6FD47029957AB911A9F4CC20D95A181A5D3.A2DBEFD67D403DB0E8BE4F4910053E4E8A7980B7',
);

# 90
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[]}|:;?/>.<"`',
    'mrtyuioplkjhgfdsazxcvbne1234567890QWER[YUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={`]}|',
);

# 88
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[]}|:;?/>.<',
    'J:|}][{=+-_)(*&;%$#@>MNBVCXZASDFGH^KLPOIUYTREWQ0987654321mnbvcxzasdfghrklpoiuytej',
);

# 87 
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$^&*()_-+={[]}|:;?/>.<',
    'tyuioplkjhgfdsazxcv<nm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$^&*()_-+={[]}|:;?/>',
);

# 86
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[|};?/>.<',
    'ertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!/#$%^&*()_-+={[|};?@',
);

# 85
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[};?/>.<',
    'ertyuiqplkjhgfdsazx$vbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#<%^&*()_-+={[};?/c',
);

# 84
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!@#$%^&*()_-+={[};?>.<',
    '<.>?;}[{=+-_)(*&^%$#@!MNBVCXZASDFGHJKLPOIUYTREWe098765432rmnbvcxzasdfghjklpoiuyt1',
);
 
# 83
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKJHGFDSAZXCVBNM!#$%^&*()_+={[};?/>.<',
    'urty8ioplkjhgfdsazxcvbqm1234567S90QWERTYUIOPLKJHGFDnAZXCVBNM!#$%^&*()_+={[};?/>.<',
);

# 82
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKHGFDSAZXCVBNM!@#$%^&*(-+={[};?/>.<',
    'Q>/?;}[{=+-(*<^%$#@!MNBVCXZASDFGHKLPOIUY8REWT0q&7654321mnbvcxzasdfghjklpoiuytrew9',
);

# 81
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKHGFDSAZXCVBNM!@#$%^&*(-+={[};?/>.',
    'C>/?;}[{=+-(*&^%$#@!MNBVYXZASDFGHKLPOIU.TREWQ0q87659321mnbvcxzasdfghjkl4oiuytrewp',
);

# 79
test_signature_decode(
    'qwertyuioplkjhgfdsazxcvbnm1234567890QWERTYUIOPLKHGFDSAZXCVBNM!@#$%^&*(-+={[};?/',
    'Z?;}[{=+-(*&^%$#@!MNBVCXRASDFGHKLPOIUYT/EWQ0q87659321mnbvcxzasdfghjkl4oiuytrewp',
);

done_testing;
