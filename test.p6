use v6;

use Post::Data;

my $elasticsearch = Post::Data.new(url => "http://localhost:9200", index => "wolf");
my %data-to-post;
%data-to-post<name> = <"PassphraseProtectorTest", "UsbProtectorTest", "AddonInstallationTest", "MultiUserTest">.pick;
%data-to-post<date> = ~DateTime.now(formatter => { sprintf "%d-%02d-%02dT%02d:%02d:%02dZ", .year, .month, .day, .hour, .minute, .second });
%data-to-post<vm> = <"W10-RS3-64", "W7-32", "W7-64", "W81-64", "W10-RS3-64", "W10-RS3-32">.pick;
%data-to-post<warehoususer> = <"dasdasd", "q23421ewsdsa", "asdasdas">.pick;
%data-to-post<warehousePassword> = <"asdawew", "sdasdsdj", "asdasds", "dasdasd">.pick;
%data-to-post<errors> = <"error", "more errors", "more more more errors">.pick;

$elasticsearch.post(data => %data-to-post, type => "test");

say $elasticsearch.output;
say $elasticsearch.exitcode;
