use v6;

use Post::Data;

my $dir = "/home/wolf/Dropbox/work/logs".IO;

my @log-files = find-files($dir);

say "Found {@log-files.elems} log files";

my $elasticsearch = Post::Data.new(url => "http://localhost:9200", index => "test");
for @log-files -> $log {
    my $log-content = $log.slurp;

    if not $log-content ~~ /Test\sGroup\sName\: | Suite \s Name \:/ {
        # Only send data when I can find following. Otherwise, the test run was not
        # started or cancelled by user.
        next;
    }

    my %data-to-post;
    %data-to-post<log> = $log.basename;

    if $log-content ~~ / "_testCaseName:" (<-[,]>+) \, / {
        %data-to-post<name> = ~$0;
    }
    else {
        %data-to-post<name> = "NotFound";
    }

    if $log-content ~~ /^ (\d**4 \- \d**2 \- \d**2 ) \s (\d**2 ':' \d**2 ':' \d**2) / {
        %data-to-post<date> = "{~$0}T{~$1}Z";
    }
    else {
        %data-to-post<date> = "NotFound";
    }

    if $log-content ~~ /"vmImages:" (<-[,]>+) / or $log-content ~~ /"using the default VM:" \s (.*?) \s? $$/ {
        %data-to-post<vms> = ~$0;
        if ~$0 ~~ / \s / {
            say $log;
            exit;
        }
    }
    else {
        %data-to-post<vms> = "NotFound";
        say "No vm " ~ $log;
    }

    if $log-content ~~ / "Set update warehouse credentials:" \s "'" (<-[']>+) "'" \s "/" \s "'" (<-[']>+) "'" \s / {
        %data-to-post<warehouseuser> = ~$0;
        %data-to-post<warehousepassword> = ~$1;
    }
    else {
        %data-to-post<warehouseuser> = "NotFound";
        %data-to-post<warehousepassword> = "NotFound";
    }

    if $log-content ~~ / ( <-[\n]>+ "Exception:" \s .*? ) $$ / {
        %data-to-post<exception>.push: ~$0;
    }
    else {
        %data-to-post<exception> = "No exception found";
    }

    if $log-content ~~ / ^^ \w+ ':' \s 'PASS' $$ / {
        %data-to-post<has_passed> = "true";
    }
    else {
        %data-to-post<has_passed> = "false";
    }

    dd %data-to-post;

    $elasticsearch.post(data => %data-to-post, type => "data");
}

sub find-files(IO::Path $path) {
    my @test-files;

    if $path.f {
            @test-files.push: $path;
            return @test-files;
    }

    for $path.IO.dir -> $file {
        if $file.d {
            @test-files.append(find-files($file));
            next;
        }

        @test-files.push: $file;
    }

    @test-files;
}
