<?php

declare(strict_types=1);

$stdin = fopen('php://stdin', 'r');
while ($line = fgets($stdin)) {
    $request = json_decode($line, true);
    if ($request && $request['method'] === 'tools/call') {
        if (isset($request['params']['arguments']['text']) && $request['params']['arguments']['text'] === 'throw') {
            $secret = 's' . 'k-ant-' . '12345678901234567890';
            fwrite(STDERR, 'Transport failed with secret ' . $secret);
            exit(1);
        }
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
