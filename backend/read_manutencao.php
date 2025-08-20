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

    $response = ["success" => false, "message" => "", "data" => null];

    // Aceita apenas GET para leitura
    if ($_SERVER["REQUEST_METHOD"] == "GET") {
        $coxo_id    = isset($_GET["coxo_id"]) ? trim($_GET["coxo_id"]) : null;
        $data_manut = isset($_GET["data_manut"]) ? trim($_GET["data_manut"]) : null;

        $conn = new mysqli($servername, $serverusername, $serverpassword, $dbname);

        if ($conn->connect_error) {
            $response["message"] = "Erro de conexão: " . $conn->connect_error;
            echo json_encode($response);
            exit;
        }

        // Monta a query dinamicamente conforme os filtros recebidos
        $query = "SELECT id, coxo_id, data_manut FROM tb_coxos WHERE 1=1";
        $params = [];
        $types = "";

        if ($coxo_id) {
            $query .= " AND coxo_id = ?";
            $params[] = $coxo_id;
            $types .= "s";
        }
        if ($data_manut) {
            $query .= " AND data_manut = ?";
            $params[] = $data_manut;
            $types .= "s";
        }

        $stmt = $conn->prepare($query);
        if ($params) {
            $stmt->bind_param($types, ...$params);
        }
        $stmt->execute();
        $result = $stmt->get_result();

        if ($result && $result->num_rows > 0) {
            $data = $result->fetch_all(MYSQLI_ASSOC);
            $response["success"] = true;
            $response["message"] = "Dados encontrados.";
            $response["data"] = $data;
        } else {
            $response["message"] = "Nenhum registro encontrado.";
        }

        echo json_encode($response);
        $stmt->close();
        $conn->close();
    } else {
        $response["message"] = "Acesso inválido.";
        echo json_encode($response);
    }
?>