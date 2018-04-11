#############################################################################
# Math/Big.pm -- usefull routines with Big numbers (BigInt/BigFloat)

package Math::Big;
use vars qw(@ISA $VERSION @EXPORT_OK);
use strict;
$VERSION = '1.11';	# Current version of this package
require  5.005;		# requires this Perl version or later

use Math::BigInt;
use Math::BigFloat;
use Exporter;
@ISA = qw( Exporter );
@EXPORT_OK = qw( primes fibonacci base hailstone factorial
		 euler bernoulli pi
		 tan cos sin cosh sinh arctan arctanh arcsin arcsinh
		 log
               );

use vars qw/@F/;				# for fibonacci()

# some often used constants:
my $four = Math::BigFloat->new(4);
my $sixteen = Math::BigFloat->new(16);
my $fone = Math::BigFloat->bone();		# pi
my $one = Math::BigInt->bone();			# hailstone, sin, cos etc
my $two = Math::BigInt->new(2);			# hailstone, sin, cos etc
my $three = Math::BigInt->new(3);		# hailstone
   
my $five = Math::BigFloat->new(5);		# for pi
my $twothreenine = Math::BigFloat->new(239);	# for pi

sub primes
  {
  my $amount = shift; $amount = 1000 if !defined $amount;
  $amount = Math::BigInt->new($amount) unless ref $amount;

  return (Math::BigInt->new(2)) if $amount < $three;
  
  $amount++;  

  # any not defined number is prime, 0,1 are not, but 2 is
  my @primes = (1,1,0); 
  my $prime = $three->copy();			# start
  my $r = 0; my $a = $amount->numify();
  for (my $i = 3; $i < $a; $i++)		# int version
    {
    $primes[$i] = $r; $r = 1-$r;
    }
  my ($cur,$add);
  # find primes
  OUTER:
  while ($prime <= $amount)
    {
    # find first unmarked, it is the next prime
    $cur = $prime;
    while ($primes[$cur])
      {
      $cur += $two; last OUTER if $cur >= $amount;	# no more to do
      }
    # $cur is now new prime
    # now strike out all multiples of $cur
    $add = $cur * $two;
    $prime = $cur + $two;			# next round start two higher
    $cur += $add;
    while ($cur <= $amount)
      {
      $primes[$cur] = 1; $cur += $add;
      }
    }

  if (!wantarray)
    {
    my $n = 0;
    for my $p (@primes)
      {
      $n++ if $p == 0;
      }
    return Math::BigInt->new($n);
    }

  my @real_primes; my $i = 0;
  while ($i < scalar @primes)
    {
    push @real_primes, Math::BigInt->new($i) if $primes[$i] == 0;
    $i ++;
    }

  @real_primes;
  }
  
sub fibonacci
  {
  my $n = shift || 0;
  $n = Math::BigInt->new($n) unless ref $n;

  return if $n->sign() ne '+';		# < 0, NaN, inf
  #####################
  # list context
  if (wantarray)
    {
    my @fib = (Math::BigInt::bzero(),Math::BigInt::bone(),Math::BigInt::bone);
    my $i = 3;							# no BigInt
    while ($i <= $n)
      {
      $fib[$i] = $fib[$i-1]+$fib[$i-2]; $i++;
      }
    return @fib;
    }
  #####################
  # scalar context

  fibonacci_fast($n);
  }

my $F;

BEGIN
  {
  #     0,1,2,3,4,5,6,7, 8, 9, 10,11,12, 13, 14, 15, 16,  17, 18, 19
  @F = (0,1,1,2,3,5,8,13,21,34,55,89,144,233,377,610,987,1597,2584,4181);
  for (my $i = 0; $i < @F; $i++)
    {
    $F[$i] = Math::BigInt->new($F[$i]);
    }
  }

sub fibonacci_fast
  {
  my $x = shift || 0;
  return $F[$x] if $x < @F;
 
  # Knuth, TAOCR Vol 1, Third Edition, p. 81
  # F(n+m) = Fm * Fn+1 + Fm-1 * Fn

  # if m is set to n+1, we get: 
  # F(n+n+1) = F(n+1) * Fn+1 + Fn * Fn
  # F(n*2+1) = F(n+1) ^ 2 + Fn ^ 2

  # so to know Fx, we must know F((x-1)/2), which only works for odd x
  # Fortunately:
  # Fx+1 = F(x) + F(x-1)
  # when x is even, then are x+1 and x-1 odd and can be calculated by the
  # same means, and from this we get Fx. 

  # starting with level 0 at Fn we fill a hash with the different n we need
  # to calculate all Fn of the previous level. Here is an example for F1000:
  
  # To calculate F1000, we need F999 and F1001 (since 1000 is even)
  # To calculate F999, we need F((999-1)/2) and F((999-1)/+2), this are 499
  # and 500. For F1001 we need likewise 500 and 501:
  # For 500, we need 499 and 501, both are already needed.
  # For 501, we need 250 and 251. An so on and on until all values at a level
  # are under 17.
  # For the deepest level we use a table-lookup. The other levels are then
  # calulated backwards, until we arive at the top and the result is then in
  # level 0.

  # level
  #   0        1         2           3    and so on
  # 1000 ->   999   ->  499 <-  ->  249
  #    |	|---->  500  |
  #    |-->  1001   ->  501 <-  ->  250    
  #                       |------>  251

  my @fibo;
  $fibo[0]->{$x} = 1;			# our final result
  # if $x is even we need these two, too
  if ($x % 1 == 0)
    {
    $fibo[0]->{$x-1} = 1; $fibo[0]->{$x+1} = 1;
    }
  # XXX
  # for statistics
  my $steps = 0; my $sum = 0; my $add = 0; my $mul = 0;
  my $level = 0;
  my $high = 1;				# keep going?
  my ($t,$t1,$f);			# helper variables
  while ($high > 0)
    {
    $level++;				# next level
    $high = 0;				# count of results > @F
#      print "at level $level (high=$high)\n";
    foreach $f (keys %{$fibo[$level-1]})
      {
      $steps ++;
      if (($f & 1) == 0)		# odd/even?
        {
        # if it is even, add $f-1 and $f+1 to last level
        # if not existing in last level, we must add
        # ($f-1-1)/2 & ($f-1-1/2)+1 to the next level, too
	$t = $f-1;
        if (!exists $fibo[$level-1]->{$t})
          {
          $fibo[$level-1]->{$t} = 1; $t--; $t /= 2;	# $t is odd
          $fibo[$level]->{$t} = 1; $fibo[$level]->{$t+1} = 1;
          } 
	$t = $f+1;
        if (!exists $fibo[$level-1]->{$t})
          {
          $fibo[$level-1]->{$t} = 1; $t--; $t /= 2;	# $t is odd
          $fibo[$level]->{$t} = 1; $fibo[$level]->{$t+1} = 1;
          } 
#        print "$f even: ",$f-1," ",$f+1," in level ",$level-1,"\n";
        } 
      else
        {
        # else add ($_-1)/2and ($_-1)/2 + 1 to this level
        $t = $f-1; $t /= 2;
        $fibo[$level]->{$t} = 1; $fibo[$level]->{$t+1} = 1;
        $high = 1 if $t+1 >= @F;	# any value not in table?
#       print "$_ odd: $t ",$t+1," in level $level (high = $high)\n";
        }
      }
    }
  # now we must fill our structure backwards with the results, combining them.
  # numbers in the last level can be looked up:
  foreach $f (keys %{$fibo[$level]})
    {
    $fibo[$level]->{$f} = $F[$f];
    }
  my $l = $level;		# for statistics
  while ($level > 0)
    {
    $level--;
    $sum += scalar keys %{$fibo[$level]};
    # first do the odd ones
    foreach $f (keys %{$fibo[$level]})
      {
      next if ($f & 1) == 0;
      $t = $f-1; $t /= 2; my $t1 = $t+1;
      $t = $fibo[$level+1]->{$t}; 
      $t1 = $fibo[$level+1]->{$t1};
      $fibo[$level]->{$f} = $t*$t+$t1*$t1;
      $mul += 2; $add ++;
      }
    # now the even ones
    foreach $f (keys %{$fibo[$level]})
      {
      next if ($f & 1) != 0;
      $fibo[$level]->{$f} = $fibo[$level]->{$f+1} - $fibo[$level]->{$f-1};
      $add ++;
      }
    }
#  print "sum $sum level $l => ",$sum/$l," steps $steps adds $add muls $mul\n";
  $fibo[0]->{$x};
  }

sub base
  {
  my ($number,$base) = @_;

  $number = Math::BigInt->new($number) unless ref $number;
  $base = Math::BigInt->new($base) unless ref $base;

  return if $number < $base;
  my $n = Math::BigInt->new(0);
  my $trial = $base;
  # 9 = 2**3 + 1
  while ($trial < $number)
    {
    $trial *= $base; $n++;
    }
  $trial /= $base; $a = $number - $trial;
  ($n,$a);
  }

sub to_base
  {
  # after an idea by Tilghman Lesher
  my ($x, $base, $alphabet) = @_;

  $x = Math::BigInt->new($x) unless ref $x;
 
  return '0' if $x->is_zero();
 
  # setup defaults:
  $base = 2 unless defined $base;
  my @digits = $alphabet ? split //, $alphabet : ('0' .. '9', 'A' .. 'Z');

  if ($base > scalar(@digits))
    {
    require Carp;
    Carp::carp("Base $base higher base than number of digits (" . scalar @digits . ") in alphabet");
    }

  if (!$x->is_pos())
    {
    require Carp;
    Carp::carp("to_base() needs a positive number");
    }

  my $o = $x->copy();
  my $r;
 
  my $result = '';
  while (!$o->is_zero)
    {
    ($o, $r) = $o->bdiv($base);
    $result = $digits[$r] . $result;
    }

  $result;
  }

sub hailstone
  {
  # return in list context the hailstone sequence, in scalar context the
  # number of steps to reach 1
  my ($n) = @_;

  $n = Math::BigInt->new($n) unless ref $n;
 
  return if $n->is_nan() || $n->is_negative();
 
  # Use the Math::BigInt lib directly for more speed, since all numbers
  # involved are positive integers.
 
  my $lib = Math::BigInt->config()->{lib};
  $n = $n->{value};
  my $three_ = $three->{value};
  my $two_ = $two->{value};

  if (wantarray)
    {
    my @seq;
    while (! $lib->_is_one($n))
      {
      # push @seq, Math::BigInt->new( $lib->_str($n) );
      push @seq, bless { value => $lib->_copy($n), sign => '+' }, "Math::BigInt";

      # was: ($n->is_odd()) ? ($n = $n * 3 + 1) : ($n = $n / 2);
      if ($lib->_is_odd($n))
        {
        $n = $lib->_mul ($n, $three_); $n = $lib->_inc ($n);

        # We now know that $n is at least 10 ( (3 * 3) + 1 ) because $n > 1
        # before we entered, and since $n was odd, it must have been at least
        # 3. So the next step is $n /= 2:
        push @seq, bless { value => $lib->_copy($n), sign => '+' }, "Math::BigInt";
        # this is better, but slower:
        #push @seq, Math::BigInt->new( $lib->_str($n) );
        # next step is $n /= 2 as usual (we save the else {} block, too)
        }
      $n = $lib->_div($n, $two_);
      }
    push @seq, Math::BigInt->bone();
    return @seq;
    }

  my $i = 1;
  while (! $lib->_is_one($n))
    {
    $i++;
    # was: ($n->is_odd()) ? ($n = $n * 3 + 1) : ($n = $n / 2);
    if ($lib->_is_odd($n))
      {
      $n = $lib->_mul ($n, $three_); $n = $lib->_inc ($n);

      # We now know that $n is at least 10 ( (3 * 3) + 1 ) because $n > 1
      # before we entered, and since $n was odd, it must have been at least
      # 3. So the next step is $n /= 2:
      # next step is $n /= 2 as usual (we save the else {} block, too)
      $i++;			# one more (we know that $n cannot be 1)
      }
    $n = $lib->_div($n, $two_);
    }
  Math::BigInt->new($i);
  }

sub factorial
  {
  # calculate n! - use Math::BigInt bfac() for speed
  my ($n) = shift;

  if (ref($n) =~ /^Math::BigInt/)
    {
    $n->copy()->bfac();
    }
  else
    {
    Math::BigInt->new($n)->bfac();
    }
  }

sub bernoulli
  {
  # returns the nth Bernoulli number. In scalar context as Math::BigFloat
  # fraction, in list context as two Math:BigFloats, which, if divided, give
  # the same result. The series runs this:
  # 1/6, 1/30, 1/42, 1/30, 5/66, 691/2730, etc

  # Since I do not have yet a way to compute this, I have a table of the
  # first 40. So bernoulli(41) will fail for now.

  my $n = shift;
 
  return if $n < 0;
  my @table_1 = ( 1,1, -1,2 );					# 0, 1
  my @table = ( 			
                1,6, -1,30, 1,42, -1,30, 5,66, -691,2730,	# 2, 4, 
                7,6, -3617,510, 43867,798,
		-174611,330,
                854513,138,
		'-236364091',2730,
		'8553103',6,
                '-23749461029',870,
                '8615841276005',14322,
		'-7709321041217',510,
		'2577687858367',6,
		'-26315271553053477373',1919190,
		'2929993913841559',6,
		'-261082718496449122051',13530,			# 40
              );
  my ($a,$b);
  if ($n < 2)
    {
    $a = Math::BigFloat->new($table_1[$n*2]);
    $b = Math::BigFloat->new($table_1[$n*2+1]);
    }
  # n is odd:
  elsif (($n & 1) == 1)
    {
    $a = Math::BigFloat->bzero();
    $b = Math::BigFloat->bone();
    }
  elsif ($n <= 40)
    {
    $n -= 2;
    $a = Math::BigFloat->new($table[$n]);
    $b = Math::BigFloat->new($table[$n+1]);
    }
  else
    {
    die 'Bernoulli numbers over 40 not yet implemented.' if $n > 40;
    }
  wantarray ? ($a,$b): $a/$b;
  }

sub euler
  {
  # calculate Euler's constant
  # first argument is x, so that result is e ** x
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = abs(shift || 1);
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # row:	  x    x^2   x^3   x^4
  #	 e = 1 + --- + --- + --- + --- ...
  # 		  1!    2!    3!    4!

  # difference for each term is thus x and n:
  # 2 copy, 2 mul, 2 add, 1 div
  
  my $e = Math::BigFloat->bone(); my $last = 0;
  my $over = $x->copy(); my $below = Math::BigFloat->bone(); my $factorial = Math::BigFloat->new(2);

  my $x_is_one = $x->is_one();

  # no $e-$last > $diff because bdiv() limit on accuracy
  while ($e->bcmp($last) != 0)
    {
    $last = $e->copy();
    $e += $over->copy()->bdiv($below,$d);
    $over *= $x unless $x_is_one;
    $below *= $factorial; $factorial->binc();
    }
  $e->bround($d-1);
  }

sub sin
  {
  # calculate sinus
  # first argument is x, so that result is sin(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:      x^3   x^5   x^7   x^9
  #    sin = x - --- + --- - --- + --- ...
  # 		  3!    5!    7!    9!
  
  # difference for each term is thus x^2 and 1,2
 
  my $sin = $x->copy(); my $last = 0;
  my $sign = 1;				# start with -=
  my $x2 = $x * $x; 			# X ^ 2, difference between terms
  my $over = $x2 * $x; 			# X ^ 3
  my $below = Math::BigFloat->new(6); my $factorial = Math::BigFloat->new(4);
  while ($sin->bcmp($last) != 0) # no $x-$last > $diff because bdiv() limit on accuracy
    {
    $last = $sin->copy();
    if ($sign == 0)
      {
      $sin += $over->copy()->bdiv($below,$d);
      }
    else
      {
      $sin -= $over->copy()->bdiv($below,$d);
      }
    $sign = 1-$sign;					# alternate
    $over *= $x2;					# $x*$x
    $below *= $factorial; $factorial++;			# n*(n+1)
    $below *= $factorial; $factorial++;
    }
  $sin->bround($d-1);
  }

sub cos
  {
  # calculate cosinus
  # first argument is x, so that result is cos(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:      x^2   x^4   x^6   x^8
  #    cos = 1 - --- + --- - --- + --- ...
  # 		  2!    4!    6!    8!
  
  # difference for each term is thus x^2 and 1,2
 
  my $cos = Math::BigFloat->bone(); my $last = 0;
  my $over = $x * $x;			# X ^ 2
  my $x2 = $over->copy();		# X ^ 2; difference between terms
  my $sign = 1;				# start with -=
  my $below = Math::BigFloat->new(2); my $factorial = Math::BigFloat->new(3);
  while ($cos->bcmp($last) != 0) # no $x-$last > $diff because bdiv() limit on accuracy
    {
    $last = $cos->copy();
    if ($sign == 0)
      {
      $cos += $over->copy()->bdiv($below,$d);
      }
    else
      {
      $cos -= $over->copy()->bdiv($below,$d);
      }
    $sign = 1-$sign;					# alternate
    $over *= $x2;					# $x*$x
    $below *= $factorial; $factorial++;			# n*(n+1)
    $below *= $factorial; $factorial++;
    }
  $cos->round($d-1);
  }

sub tan
  {
  # calculate tangens
  # first argument is x, so that result is tan(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:  1         2            3            4           5  

  #		      x^3          x^5          x^7          x^9
  #    tan = x + 1 * -----  + 2 * ----- + 17 * ----- + 62 * ----- ...
  # 		       3           15           315         2835
  #
  #  2^2n * ( 2^2n - 1) * Bn * x^(2n-1)          256*255 * 1 * x^7   17 
  #  ---------------------------------- : n=4:  ----------------- = --- * x^7
  #               (2n)!                            40320 * 30       315
  # 
  # 8! = 40320, B4 (Bernoully number 4) = 1/30

  # for each term we need: 2^2n, but if we have 2^2(n-1) we use n = (n-1)*2
  # 2 copy, 7 bmul, 2 bdiv, 3 badd, 1 bernoulli 
 
  my $tan = $x->copy(); my $last = 0;
  my $x2 = $x*$x;
  my $over = $x2*$x;
  my $below = Math::BigFloat->new(24);	 	# (1*2*3*4) (2n)!
  my $factorial = Math::BigFloat->new(5);	# for next (2n)!
  my $two_n = Math::BigFloat->new(16);	 	# 2^2n
  my $two_factor = Math::BigFloat->new(4); 	# 2^2(n+1) = $two_n * $two_factor
  my ($b,$b1,$b2); $b = 4;
  while ($tan->bcmp($last) != 0) # no $x-$last > $diff because bdiv() limit on accuracy
    {
    $last = $tan->copy();
    ($b1,$b2) = bernoulli($b);
    $tan += $over->copy()->bmul($two_n)->bmul($two_n - $fone)->bmul($b1->babs())->bdiv($below,$d)->bdiv($b2,$d);
    $over *= $x2;				# x^3, x^5 etc
    $below *= $factorial; $factorial++;		# n*(n+1)
    $below *= $factorial; $factorial++;
    $two_n *= $two_factor;			# 2^2(n+1) = 2^2n * 4
    $b += 2;					# next bernoulli index
    last if $b > 40;				# safeguard
    }
  $tan->round($d-1);
  }

sub sinh
  {
  # calculate sinus hyperbolicus
  # first argument is x, so that result is sinh(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:       x^3   x^5   x^7
  #    sinh = x + --- + --- + --- ...
  # 	           3!    5!    7!
  
  # difference for each term is thus x^2 and 1,2
 
  my $sinh = $x->copy(); my $last = 0;
  my $x2 = $x*$x; 
  my $over = $x2 * $x; my $below = Math::BigFloat->new(6); my $factorial = Math::BigFloat->new(4);
  while ($sinh->bcmp($last)) # no $x-$last > $diff because bdiv() limit on accuracy
    {
    $last = $sinh->copy();
    $sinh += $over->copy()->bdiv($below,$d);
    $over *= $x2;					# $x*$x
    $below *= $factorial; $factorial++;			# n*(n+1)
    $below *= $factorial; $factorial++;
    }
  $sinh->bround($d-1);
  }

sub cosh
  {
  # calculate cosinus hyperbolicus
  # first argument is x, so that result is cosh(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:       x^2   x^4   x^6
  #    cosh = x + --- + --- + --- ...
  # 	           2!    4!    6!
  
  # difference for each term is thus x^2 and 1,2
 
  my $cosh = Math::BigFloat->bone(); my $last = 0;
  my $x2 = $x*$x; 
  my $over = $x2; my $below = Math::BigFloat->new(); my $factorial = Math::BigFloat->new(3);
  while ($cosh->bcmp($last)) # no $x-$last > $diff because bdiv() limit on accuracy
    {
    $last = $cosh->copy();
    $cosh += $over->copy()->bdiv($below,$d);
    $over *= $x2;					# $x*$x
    $below *= $factorial; $factorial++;			# n*(n+1)
    $below *= $factorial; $factorial++;
    }
  $cosh->bround($d-1);
  }

sub arctan
  {
  # calculate arcus tangens
  # first argument is x, so that result is arctan(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:      x^3   x^5   x^7   x^9
  # arctan = x - --- + --- - --- + --- ...
  # 		  3     5    7      9
  
  # difference for each term is thus x^2 and 2:
  # 2 copy, 1 bmul, 1 badd, 1 bdiv
 
  my $arctan = $x->copy(); my $last = 0;
  my $x2 = $x*$x; 
  my $over = $x2*$x; my $below = Math::BigFloat->new(3); my $add = Math::BigFloat->new(2);
  my $sign = 1;
  while ($arctan->bcmp($last)) # no $x-$last > $diff because bdiv() limit on A
    {
    $last = $arctan->copy();
    if ($sign == 0)
      {
      $arctan += $over->copy()->bdiv($below,$d);
      }
    else
      {
      $arctan -= $over->copy()->bdiv($below,$d);
      }
    $sign = 1-$sign;					# alternate
    $over *= $x2;					# $x*$x
    $below += $add;
    }
  $arctan->bround($d-1);
  }

sub arctanh
  {
  # calculate arcus tangens hyperbolicus
  # first argument is x, so that result is arctanh(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:       x^3   x^5   x^7   x^9
  # arctanh = x + --- + --- + --- + --- + ...
  # 	 	   3     5    7      9
  
  # difference for each term is thus x^2 and 2:
  # 2 copy, 1 bmul, 1 badd, 1 bdiv
 
  my $arctanh = $x->copy(); my $last = 0;
  my $x2 = $x*$x; 
  my $over = $x2*$x; my $below = Math::BigFloat->new(3); my $add = Math::BigFloat->new(2);
  while ($arctanh->bcmp($last)) # no $x-$last > $diff because bdiv() limit on A
    {
    $last = $arctanh->copy();
    $arctanh += $over->copy()->bdiv($below,$d);
    $over *= $x2;					# $x*$x
    $below += $add;
    }
  $arctanh->bround($d-1);
  }

sub arcsin
  {
  # calculate arcus sinus
  # first argument is x, so that result is arcsin(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:      1 * x^3   1 * 3 * x^5   1 * 3 * 5 * x^7  
  # arcsin = x + ------- + ----------- + --------------- + ...
  # 		 2 *  3    2 * 4 *  5    2 * 4 * 6 *   7
  
  # difference for each term is thus x^2 and two muls (fac1, fac2):
  # 3 copy, 3 bmul, 1 bdiv, 3 badd

  my $arcsin = $x->copy(); my $last = 0;
  my $x2 = $x*$x; 
  my $over = $x2*$x; my $below = Math::BigFloat->new(6); 
  my $fac1 = Math::BigFloat->new(1);
  my $fac2 = Math::BigFloat->new(2);
  my $two = Math::BigFloat->new(2);
  while ($arcsin->bcmp($last)) # no $x-$last > $diff because bdiv() limit on A
    {
    $last = $arcsin->copy();
    $arcsin += $over->copy()->bmul($fac1)->bdiv($below->copy->bmul($fac2),$d);
    $over *= $x2;					# $x*$x
    $below += $one;
    $fac1 += $two;
    $fac2 += $two;
    }
  $arcsin->bround($d-1);
  }

sub arcsinh
  {
  # calculate arcus sinus hyperbolicus
  # first argument is x, so that result is arcsinh(x)
  # Second argument is accuracy (number of significant digits), it
  # stops when at least so much plus one digits are 'stable' and then
  # rounds it. Default is 42.
  my $x = shift; $x = 0 if !defined $x;
  my $d = abs(shift || 42); $d = abs($d)+1;

  $x = Math::BigFloat->new($x) if ref($x) ne 'Math::BigFloat';
  
  # taylor:      1 * x^3   1 * 3 * x^5   1 * 3 * 5 * x^7  
  # arcsin = x - ------- + ----------- - --------------- + ...
  # 		 2 *  3    2 * 4 *  5    2 * 4 * 6 *   7
  
  # difference for each term is thus x^2 and two muls (fac1, fac2):
  # 3 copy, 3 bmul, 1 bdiv, 3 badd

  my $arcsinh = $x->copy(); my $last = 0;
  my $x2 = $x*$x; my $sign = 0; 
  my $over = $x2*$x; my $below = 6; 
  my $fac1 = Math::BigInt->new(1);
  my $fac2 = Math::BigInt->new(2);
  while ($arcsinh ne $last) # no $x-$last > $diff because bdiv() limit on A
    {
    $last = $arcsinh->copy();
    if ($sign == 0)
      {
      $arcsinh += $over->copy()->bmul(
        $fac1)->bdiv($below->copy->bmul($fac2),$d);
      }
    else
      {
      $arcsinh -= $over->copy()->bmul(
        $fac1)->bdiv($below->copy->bmul($fac2),$d);
      }
    $over *= $x2;					# $x*$x
    $below += $one;
    $fac1 += $two;
    $fac2 += $two;
    }
  $arcsinh->round($d-1);
  }

sub log
  {
  my ($x,$base,$d) = @_;

  my $y;
  if (!ref($x) || !$x->isa('Math::BigFloat'))
    {
    $y = Math::BigFloat->new($x);
    }
  else
    {
    $y = $x->copy();
    }
  $y->blog($base,$d);
  $y;
  }

sub pi
  {
  # calculate PI (as suggested by Robert Creager)
  my $digits = abs(shift || 1024);

  my $d = $digits+5;

  my $pi =  $sixteen * arctan( scalar $fone->copy()->bdiv($five,$d), $d )
             - $four * arctan( scalar $fone->copy()->bdiv($twothreenine,$d), $d);
  $pi->bround($digits+1);	# +1 for the "3."
  }

1;
__END__

#############################################################################

=head1 NAME

Math::Big - routines (cos,sin,primes,hailstone,euler,fibbonaci etc) with big numbers

=head1 SYNOPSIS

    use Math::Big qw/primes fibonacci hailstone factors wheel
      cos sin tan euler bernoulli arctan arcsin pi/;

    @primes	= primes(100);		# first 100 primes
    $prime	= primes(100);		# 100th prime
    @fib	= fibonacci (100);	# first 100 fibonacci numbers
    $fib_1000	= fibonacci (1000);	# 1000th fibonacci number
    $hailstone	= hailstone (1000);	# length of sequence
    @hailstone	= hailstone (127);	# the entire sequence
    
    $factorial	= factorial(1000);	# factorial 1000!
 
    $e = euler(1,64); 			# e to 64 digits

    $b3 = bernoulli(3);

    $cos	= cos(0.5,128);		# cosinus to 128 digits
    $sin	= sin(0.5,128);		# sinus to 128 digits
    $cosh	= cosh(0.5,128);	# cosinus hyperbolicus to 128 digits
    $sinh	= sinh(0.5,128);	# sinus hyperbolicus to 128 digits
    $tan	= tan(0.5,128);		# tangens to 128 digits
    $arctan	= arctan(0.5,64);	# arcus tangens to 64 digits
    $arcsin	= arcsin(0.5,32);	# arcus sinus to 32 digits
    $arcsinh	= arcsin(0.5,18);	# arcus sinus hyperbolicus to 18 digits

    $pi		= pi(1024);		# first 1024 digits
    $log	= log(64,2);		# $log==6, because 2**6==64
    $log	= log(100,10);		# $log==2, because 10**2==100
    $log	= log(100);		# base defaults to 10: $log==2

=head1 REQUIRES

perl5.005, Exporter, Math::BigInt, Math::BigFloat

=head1 EXPORTS

Exports nothing on default, but can export C<primes()>, C<fibonacci()>,
C<hailstone()>, C<bernoulli>, C<euler>, C<sin>, C<cos>, C<tan>, C<cosh>,
C<sinh>, C<arctan>, C<arcsin>, C<arcsinh>, C<pi>, C<log> and C<factorial>.

=head1 DESCRIPTION

This module contains some routines that may come in handy when you want to
do some math with really, really big (or small) numbers. These are primarily
examples.

=head1 METHODS

=head2 B<primes()>

	@primes = primes($n);
	$primes = primes($n);

Calculates all the primes below N and returns them as array. In scalar context
returns the number of primes below N.
  
This uses an optimized version of the B<Sieve of Eratosthenes>, which takes
half of the time and half of the space, but is still O(N). Or in other words,
quite slow.

=head2 B<fibonacci()>

	@fib = fibonacci($n);
	$fib = fibonacci($n);

Calculates the first N fibonacci numbers and returns them as array.
In scalar context returns the Nth number of the Fibonacci series.

The scalar context version uses an ultra-fast conquer-divide style algorithm
to calculate the result and is many times faster than the straightforward way
of calculating the linear sum.

=head2 B<hailstone()>

	@hail = hailstone($n);		# sequence
	$hail = hailstone($n);		# length of sequence

Calculates the I<Hailstone> sequence for the number N. This sequence is defined 
as follows:

	while (N != 0)
	  {
          if (N is even)
	    {
            N is N /2
   	    }
          else
	    {
            N = N * 3 +1
	    }
          }

It is not yet proven whether for every N the sequence reaches 1, but it
apparently does so. The number of steps is somewhat chaotically.

=head2 B<base()>

	($n,$a) = base($number,$base);

Reduces a number to C<$base> to the C<$n>th power plus C<$a>. Example:

	use Math::BigInt :constant;
	use Math::Big qw/base/;

	print base ( 2 ** 150 + 42,2);

This will print 150 and 42.

=head2 B<to_base()>

	$string = to_base($number,$base);

	$string = to_base($number,$base, $alphabet);

Returns a string of C<$number> in base C<$base>. The alphabet is optional if
C<$base> is less or equal than 36. C<$alphabet> is a string.

Examples:

	print to_base(15,2);		# 1111
	print to_base(15,16);		# F
	print to_base(31,16);		# 1F

=head2 B<factorial()>

	$n = factorial($number);

Calculate C<n!> for C<n >= 0>.

Uses internally Math::BigInt's bfac() method. 

=head2 B<bernoulli()>

	$b = bernoulli($n);
	($c,$d) = bernoulli($n);	# $b = $c/$d

Calculate the Nth number in the I<Bernoulli> series. Only the first 40 are
defined for now.

=head2 B<euler()>

	$e = euler($x,$d);

Calculate I<Euler's constant> to the power of $x (usual 1), to $d digits.
Defaults to 1 and 42 digits.

=head2 B<sin()>

	$sin = sin($x,$d);

Calculate I<sinus> of C<$x>, to C<$d> digits.

=head2 B<cos()>

	$cos = cos($x,$d);

Calculate I<cosinus> of C<$x>, to C<$d> digits.

=head2 B<tan()>

	$tan = tan($x,$d);

Calculate I<tangens> of C<$x>, to C<$d> digits.

=head2 B<arctan()>

	$arctan = arctan($x,$d);

Calculate I<arcus tangens> of C<$x>, to C<$d> digits.

=head2 B<arcsin()>

	$arcsin = arcsin($x,$d);

Calculate I<arcus sinus> of C<$x>, to C<$d> digits.

=head2 B<arcsinh()>

	$arcsinh = arcsinh($x,$d);

Calculate I<arcus sinus hyperbolicus> of C<$x>, to C<$d> digits.

=head2 B<cosh()>

	$cosh = cosh($x,$d);

Calculate I<cosinus hyperbolicus> of C<$x>, to C<$d> digits.

=head2 B<sinh()>

	$sinh = sinh($x,$d);

Calculate I<sinus hyperbolicus> of $<$x>, to C<$d> digits.

=head2 B<pi()>

	$pi = pi($N);

The number PI to C<$N> digits after the dot.

=head2 B<log()>

	$log = log($number,$base,$A);

Calculates the logarithmn of C<$number> to base C<$base>, with C<$A> digits accuracy
and returns a new number as the result (leaving C<$number> alone).

BigInts are promoted to BigFloats, meaning you will never get a truncated
integer result like when using C<Math::BigInt::blog>.

=head1 BUGS

=over 2

=item *

Primes and the Fibonacci series use an array of size N and will not be able
to calculate big sequences due to memory constraints.

The exception is fibonacci in scalar context, this is able to calculate
arbitrarily big numbers in O(N) time:

	use Math::Big;
	use Math::BigInt qw/:constant/;

	$fib = Math::Big::fibonacci( 2 ** 320 );

=item *

The Bernoulli numbers are not yet calculated, but looked up in a table, which
has only 40 elements. So C<bernoulli($x)> with $x > 42 will fail.

If you know of an algorithmn to calculate them, please drop me a note.

=back

=head1 LICENSE

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=head1 AUTHOR

If you use this module in one of your projects, then please email me. I want
to hear about how my code helps you ;)

Quite a lot of ideas from other people, especially D. E. Knuth, have been used,
thank you!

Tels http://bloodgate.com 2001 - 2005.

=cut

1;
