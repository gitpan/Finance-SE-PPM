use 5.006;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.

WriteMakefile(
    'NAME'		=> 'Finance::SE::PPM',
#    depend => { '$(FIRST_MAKEFILE)' => '$(VERSION_FROM)' },
    'VERSION_FROM'	=> 'PPM.pm', 
    'PREREQ_PM'		=> {
		'Class::XPath'      => 0,
		'HTML::TreeBuilder' => 0,
		'Crypt::SSLeay'     => 0,
	}, 
    ($] >= 5.005 ?    ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM => 'PPM.pm', # retrieve abstract from module
       AUTHOR     => 'Erwan Lemonnier <erwlem@cpan.org>') : ()),
);
