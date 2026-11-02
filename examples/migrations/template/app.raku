use lib 'lib';
use Red;
use Task;
use Cro::HTTP::Router;
use Cro::HTTP::Server;
my $application = route {
    get -> {
        content 'text/html', '<h1>Task workshop</h1><p>Fields: '
            ~ Task.^columns.map(*.column.name).join(', ') ~ '</p><pre>'
            ~ Task.^all.List.map({
                .title.trans(['&', '<', '>'] => ['&amp;', '&lt;', '&gt;'])
            }).join("\n")
            ~ '</pre><form action="/tasks" method="post"><input name="title"><button>Add</button></form>';
    }
    get -> 'health' { content 'text/plain', 'ok' }
    get -> 'version' { content 'text/plain', %*ENV<RELEASE> // 'development' }
    post -> 'tasks' {
        request-body -> (:$title!) {
            my %values = :$title;
            %values<description> = 'Created by application'
                if Task.^columns.first(*.column.name eq 'description').defined;
            Task.^create(|%values);
            content 'text/plain', 'created';
        }
    }
};
my $server = Cro::HTTP::Server.new(:host<0.0.0.0>, :port(8080), :$application);
$server.start;
react whenever signal(SIGINT) { $server.stop; exit }
