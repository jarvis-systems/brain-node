<?php

declare(strict_types=1);

$stdin = fopen('php://stdin', 'r');
while ($line = fgets($stdin)) {
    $request = json_decode($line, true);
    if ($request && $request['method'] === 'tools/call') {
        $response = [
            'jsonrpc' => '2.0',
            'id' => $request['id'],
            'result' => [
                'echo' => $request['params']['arguments']['text'] ?? 'hello',
                'sensitive_token' => 'SECRET_VALUE',
            ]
        ];
        echo json_encode($response) . "
";
        exit(0);
    }
}
