use v6;

use Post::Data;

# blacklist to filter error message that I'm not interested in.
my @error-blacklist = (
    /:i 'Management Communications System already exists'/,
    /:i 'send heartbeat fails'/,
    /:i 'UnknownHostException: p0.q.hmr.sophos.com: unknown error'/,
    /:i 'ThunderResourceProvider.uncaughtException (ThreadUtils.groovy:89)'/,
    /:i 'CommandExecutor already exists'/,
    /:i 'beforeConfiguration catch exception'/,
    /:i 'exit-code: 65535'/,
    /:i 'found unknown actor type: INSTANCE'/,
    /:i 'already exists.'/,
);

my $dir = "/home/wolfgangbanaston/repos/lwrap/logs".IO;

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

    if $log-content ~~ / "_testCaseName:" (<-[,]>+) "," / {
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
        #%data-to-post<warehousepassword> = ~$1;
    }
    else {
        %data-to-post<warehouseuser> = "NotFound";
        #%data-to-post<warehousepassword> = "NotFound";
    }

    if $log-content ~~ /^^ <-[:]>+ ":" \s "PASS" $$/ {
        %data-to-post<has_passed> = "true";
    }
    else {
        %data-to-post<has_passed> = "false";
    }

    if $log-content ~~ /^^ ('https://thunder.cloud.sophos'.*)$$/ {
        %data-to-post<thunder_link> = ~$0;
    }
    else
    {
        %data-to-post<thunder_link> = "NotFound";
    }

    if %data-to-post<has_passed> eq "false" {
        my @errors = ();
        my $thunder-link = "";

        my $curLogEntry = "";
        for $log-content.split(/\n/) -> $line {
            # check whether it is a new log entry
            if $line ~~ /^^ \d+\-\d+\-\d+ \s \d+\:\d+\:\d+ / {
                # new log entry. Print last one if desired
                if $curLogEntry ~~ /'[ERROR'/ {
                    # A lot of errors are caused by Lightning/Thunder and can be ignored.
                    # The test run can pass anyway. So, I use a blacklist to filter out these errors
                    unless $curLogEntry ~~ @error-blacklist.any {
                        @errors.push($curLogEntry)
                    }
                    $curLogEntry = "";
                    next;
                }
                else {
                    $curLogEntry = $line;
                    next;
                }
            }
            else {
                # no timestamp found. Expect it to be a log entry with more
                # than one line.
                $curLogEntry ~= "\n$line";
            }
        }

        if @errors.elems > 0 {
            %data-to-post<errors> = @errors;
        }
        else {
            %data-to-post<errors> = "Nothing found";
        }
    }

    if $log-content ~~ / ( <-[\n]>+ "Exception:" \s .*? ) $$ / {
        %data-to-post<exception>.push: ~$0;
    }
    else {
        %data-to-post<exception> = "No exception found";
    }

#    dd %data-to-post;

    $elasticsearch.post(data => %data-to-post, type => "data");
}

sub find-files(IO::Path $path) {
    my @test-files;
    say "Check $path";

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
