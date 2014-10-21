# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl 1.t'

#########################


use Test::More tests => 10;
BEGIN { use_ok('CGI::Application::Plugin::TemplateRunner') };

#########################

# Test CGI::App class
{ 
	package MyTestApp;
	use base 'CGI::Application';
	use CGI::Application::Plugin::TemplateRunner qw(prepare_tmpl show_tmpl);
	sub setup {
               my $self = shift;
               $self->start_mode('mode1');
               $self->run_modes(
                       'mode1' => 'show_tmpl',
               );
         }

}

{
	my $testname = "simple prepare_tmpl";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	my $t = $app->prepare_tmpl('CAPH.html');
	$t = $t->output;
	is (index($t, 'Hello world!'),0, $testname);
}

{
	my $testname = "using a nested hash";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	my $t = $app->prepare_tmpl('CAPH.html');
	$t = $t->output;
	is (index($t, '123'),51, $testname);
}

{
	my $testname = "using a sub routine";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	$app->param('a_param'=>'wowsers');
	my $t = $app->prepare_tmpl('CAPH.html');
	$t = $t->output;
	is (index($t, 'wowsers'),56, $testname);
}

{
	my $testname = "extras";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	my $t = $app->prepare_tmpl('CAPH.html',
		'subroutine' => 'extras');
	$t = $t->output;
	is (index($t, 'extras'),56, $testname);
}

{
	my $testname = "cookies, CGI params, app params";
	$ENV{HTTP_COOKIE} = "foo=baz";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	$app->query->param(foo => 'bar');
	$app->param(blah => {one => 'eins', two=>'zwei'});
	my $t = $app->prepare_tmpl('CAPH.html');
	$t = $t->output;
	is (index($t, 'bar'),58, $testname);
	is (index($t, 'baz'),63, $testname);
	is (index($t, 'zwei'),68, $testname);
}

{
	my $testname = "runmode";
	$ENV{CGI_APP_RETURN_ONLY} = 1;
	$ENV{PATH_INFO} = "/CAPH.html";
	my $app = new MyTestApp();
	$app->tmpl_path('t/tmplroot');
	my $t = $app->run;
	ok ($t =~ m/Hello world!/, $testname);
}

{
	my $testname = "base class";
	$ENV{CGI_APP_RETURN_ONLY} = 1;
	$ENV{PATH_INFO} = "/CAPH.html";
	my $app = new CGI::Application::Plugin::TemplateRunner();
	$app->tmpl_path('t/tmplroot');
	my $t = $app->run;
	ok ($t =~ m/Hello world!/, $testname);
}




