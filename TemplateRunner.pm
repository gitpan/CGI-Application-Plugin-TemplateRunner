package CGI::Application::Plugin::TemplateRunner;

use strict;
use HTML::Template;
use base qw(CGI::Application Exporter);



our @EXPORT_OK = qw[
	show_tmpl
	prepare_tmpl
	fill_tmpl
	];

our $VERSION = '0.03';

sub show_tmpl{
	my ($self) = @_;
	my $q = $self->query;
	my $path = $q->path_info || '/';
	$path .= 'index.html' if ($path =~ m{/$} );
	# we only do .html 
	unless ($path =~ m{\.html$}){
		$self->header_add(-status => 404 );
		warn "This runmode only serves HTML files (.html), not $path \n";
		return;
	};
	my $page = $self->prepare_tmpl($path);
	return $page->output;
}

sub prepare_tmpl{
	my ($self, $name, %extras) = @_;
	
	my $base = $self->tmpl_path;
	$base = $base->[0] if ref $base; 
	die "you need to defined a tmpl_path for your application\n" unless $base;
	
	# load the template
	my $cache = 'cache';
	$cache = 'shared_cache' if $IPC::SharedCache::VERSION;
	my $tmpl = $self->load_tmpl($name, 
		die_on_bad_params => 0,
		loop_context_vars => 1,
		global_vars => 1,
		$cache => 1,
		);
	
	# load a data file if available
	if (-e "$base/$name.pl"){
		my $result = do "$base/$name.pl";
		if ($@){
			warn "/$base/$name.pl could not be compiled: $@ $!\n";
		}else{
			fill_tmpl($self, $tmpl, $result);
		}
	}
	
	# fill in cookies and params
	my $q = $self->query;
	foreach ($q->param){
		$tmpl->param("/request/$_" => scalar $q->param($_));
	}
	foreach ($q->cookie){
		$tmpl->param("/cookie/$_" => scalar $q->cookie($_));
	}
	fill_tmpl($self, $tmpl, $self->{__PARAMS}, '/app');
	
	fill_tmpl($self, $tmpl, \%extras) if keys %extras;
	return $tmpl;	
}

sub fill_tmpl{
	my ($self, $tmpl, $data, $prefix) = @_;
	$prefix = '' unless defined $prefix;
	# call code refs 
	if (ref $data eq 'CODE'){
		$data = eval{$data->($self)};
		if ($@){
			warn "data sub [$prefix] could not be executed: $@\n";
		}
		fill_tmpl($self, $tmpl, $data, $prefix);
		return;
	}
	# dive into hash refs
	if (ref $data eq 'HASH'){
		while (my ($key, $value) = each %$data){
			fill_tmpl($self, $tmpl, $value, "$prefix/$key");
		}
		return;
	}
	# anything else try to stuff into the template	
	eval { $tmpl->param($prefix => $data);} if defined $data;
	warn $@ if $@;
}

# if used as a base class ( not a plugin)
# then set up properly
sub setup{
	my $self = shift;
	$self->start_mode('show_tmpl');
	$self->run_modes(
		'show_tmpl' => 'show_tmpl');
}

1;
__END__

=head1 NAME

CGI::Application::Plugin::TemplateRunner - CGI::App plugin to display HTML::Templates

=head1 SYNOPSIS

  package MyApp;
  use base 'CGI::Application'
  use CGI::Application::Plugin::TemplateRunner
  	qw( show_tmpl);
  
  sub setup{
	  my $self = shift;
	  $self->start_mode('show_tmpl');
	  $self->run_modes(
                       'show_tmpl' => 'show_tmpl',
		       'some_action' => 'some_action',
               );
  }
  
  sub some_action{
	  my $self = shift;
	  # do some stuff with the database
	  return $self->show_tmpl;
  }


=head1 DESCRIPTION

This module is a plugin for L<CGI::Application>
that provides a runmode to automatically get
the name of an HTML::Template from the path_info 
string, load the template, fill it with data from an
associated Perl data file and display the template.

=head2 EXPORT

There are three methods that you can use in CGI::App subclass.
None of them are exported by default, you
have to explicitly import them.

=head3 show_tmpl

This is a runmode. It extracts a page name
from path_info. That name must end in .html 
and a file of the same name must be present in the applications tmpl_path
(if you have multiple tmpl_path, in the first one).
For example if you have

	http://mydomain/mycgi.cgi/bbs/index.html

it will look for 

	$tmpl_path/bbs/index.html

That template will be loaded and displayed.
See the detailed description below about where the
data for the template is coming from.

=head3 prepare_tmpl

This method is used internally to load the template
and fill in the data. You can also use it inside of
your own runmodes if you want.

	my $tmpl = $self->prepare_tmpl(
		$filename, %extras);

You can use %extras to specify additional data to 
be used as template parameters
(not found or overriding the data from the data file).

=head3 fill_tmpl

Another internal method that takes an HTML::Template
instance and some data to put into it.
It basically wraps around $tmpl->param to provide
the additional functionality needed by this plugin 
(descending into hashes, calling coderefs).

	$self->fill_tmpl($tmpl, {
	'/somehash' => { one => 1, two=>2 }};

=head2 Where does the template get its data?

=head3 CGI parameters and cookies

CGI request parameters and cookies are 
automatically made available to the template.
If you have

	http://mydomain/mycgi.cgi/bbs/index.html?page=4

you can get it as

	<tmpl_var /request/page>

and your cookie "ID" will become

	<tmpl_var /cookie/id>

=head3 Application parameters

Parameters set for the CGI::Application instance
(using $app->param() ) are also automatically available
to the template

	$app->param(foo => bar);
	
	<tmpl_var /app/foo>


=head3 The data file

When this module loads a template, it also tries
to load an associated data file, which has the same
name as the template plus ".pl" at the end.
So for /bbs/index.html it will look for /bbs/index.html.pl
(you have to put the data file next to the HTML file
into your tmpl_path)

That data file is just a Perl file and gets eval'ed.
It must return a hash ref with the data.

Here is an example:

	{
		page_title => 'BBS page',
		# becomes <tmpl_var /page_title>
		
		categories => [
		{ name => 'Sports',  link => 'sports.html'},
		{ name => 'TV', link => 'tv.html'},
		],
		# becomes <tmpl_loop categories>
		
		nested => { 
			a=> 1, b => 2
		},
		# become <tmpl_var nested/a>
		# and <tmpl_var nested/b>
		
		articles => sub{
			my $app = shift;
			# subroutines get the CGI::App
			# instance as their only parameter
			my $q = $app->query;
			my $page = $q->param('page')||1;
			my $total = MyDB::get_article_count;
			my $page = MyDB::get_article_list($page);
			return {
				total => $total,
				page => $page};
		};
		# becomes
		# <tmpl_var articles/total>
		# <tmpl_loop articles/page>
	}

=head3 extra parameters to prepare_tmpl

If you use prepare_tmpl in your runmodes,
you can stuff in extra data:

       my $tmpl = $self->prepare_tmpl(
		$filename, 'more' => 'data')
		
	<tmpl_var /more>


=head2 Using this class as a CGI::App subclass

For very simple applications, especially ones that
only display some data but do not allow to edit it,
the single runmode provided by this
module is probably all you need. In this case,
you do not have to make your own CGI::App subclass
at all, but can use this module directly from your
instance scripts:

	#!/usr/bin/perl
	use CGI::Application::Plugin::TemplateRunner;
	my $app = new CGI::Application::Plugin::TemplateRunner();
	$app->tmpl_path('/home/webapps/thisone/tmpl');
	$app->run;


=head1 SEE ALSO

=over

=item *

L<CGI::Application>

=item *

The CGI::App wiki at 
L<http://twiki.med.yale.edu/twiki2/bin/view/CGIapp/WebHome>.

=back

=head1 AUTHOR

Thilo Planz, E<lt>thiloplanz@web.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2004 by Thilo Planz

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
