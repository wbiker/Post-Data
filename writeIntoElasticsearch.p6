use v6;

use Post::Data;

my $dir = "";

my @log-files = find-files($dir);

say "Found {$log-files.elems} log files";

my $elasticsearch = Post::Data.new(url => "http://localhost:9200", index => "test");
for @log-files -> $log {
    my %data-to-post;

    my $log-content = $log.slurp;
    if $log-content ~~ / "_testCaseName:" (<-[,]>+) , / {
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

    if $log-content ~~ /"vmImages:" (<-[\s]>+) \s / {
        %data-to-post<vms> = ~$0;
    }
    else {
        %data-to-post<vms> = "NotFound";
    }

    if $log-content ~~ / "Set update warehouse credentials:" \s "'" (<-[']>+) "'" \s / \s "'" (<-[']>+) "'" \s / {
        %data-to-post<warehouseuser> = ~$0;
        %data-to-post<warehousepassword> = ~$1;
    }
    else {
        %data-to-post<warehouseuser> = "NotFound";
        %data-to-post<warehousepassword> = "NotFound";
    }

    dd %data-to-post;
    #$elasticsearch.post(data => %data-to-post, type => "data");
}

sub find-files(IO::Path $path) {
    my @test-files;

    if $path.f {
        if $path.basename ~~ /".log" $/ {
            @test-files.push: $path;
            return @test-files;
        }
    }

    for $path.IO.dir -> $file {
        if $file.d {
            @test-files.append(find-files($file));
            next;
        }

        next unless $file ~~ /".log" $/;
        @test-files.push: $file;
    }

    @test-files;
}
