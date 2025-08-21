<?php
    header('Content-Type: application/json');
    set_error_handler(function($errno, $errstr, $errfile, $errline) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "PHP Error: $errstr in $errfile on line $errline"
        ]);
        exit;
    });
    set_exception_handler(function($exception) {
        http_response_code(500);
        echo json_encode([
            "success" => false,
            "message" => "Exception: " . $exception->getMessage()
        ]);
        exit;
    });

    $servername = "localhost";
    $serverusername = "root";
    $serverpassword = "root";
    $dbname = "coxos_db";

    $response = ["success" => false, "message" => ""];

    if ($_SERVER["REQUEST_METHOD"] == "POST") {
        $coxo_id = isset($_POST["coxo_idPost"]) ? trim($_POST["coxo_idPost"]) : null;
        $data_manut = isset($_POST["data_manutPost"]) ? trim($_POST["data_manutPost"]) : null;
        $usuario    = isset($_POST["usuarioPost"]) ? trim($_POST["usuarioPost"]) : null;

        if (!$coxo_id || !$data_manut || !$usuario) {
            $response["message"] = "Erro: coxo_id, Data e Usuário são obrigatórios.";
            echo json_encode($response);
            exit;
        }

        $conn = new mysqli($servername, $serverusername, $serverpassword, $dbname);

        if ($conn->connect_error) {
            $response["message"] = "Erro de conexão: " . $conn->connect_error;
            echo json_encode($response);
            exit;
        }

        // Apenas INSERT
        $stmt = $conn->prepare("INSERT INTO tb_coxos (coxo_id, data_manut, usuario) VALUES (?, ?, ?)");
        if ($stmt === false) {
            $response["message"] = "Erro na preparação da consulta: " . $conn->error;
            echo json_encode($response);
            exit;
        }
        $stmt->bind_param("sss", $coxo_id, $data_manut, $usuario);

        if ($stmt->execute()) {
            $response["success"] = true;
            $response["message"] = "Manutenção registrada com sucesso!";
        } else {
            $response["message"] = "Erro ao registrar: " . $stmt->error;
        }

        echo json_encode($response);
        $stmt->close();
        $conn->close();
    } else {
        $response["message"] = "Acesso inválido.";
        echo json_encode($response);
    }
?>