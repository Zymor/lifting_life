@echo off
echo ========================================================
echo          LIFTING LIFE - PLATFORM LAUNCHER
echo ========================================================
echo.
echo Starting Lifting Life Authorized Backend on Port 4000...
start "Lifting Life Backend (Port 4000)" cmd /k "set PATH=C:\Users\Reatanak\AppData\Local\Programs\node;%PATH% && cd lifting-life-backend && npm start"

timeout /t 3 /nobreak >nul

echo Starting Lifting Life Admin Portal on Port 3000...
start "Lifting Life Admin (Port 3000)" cmd /k "set PATH=C:\Users\Reatanak\AppData\Local\Programs\node;%PATH% && cd lifting-life-admin && npm run dev"

timeout /t 2 /nobreak >nul

echo Starting Lifting Life User Website on Port 8080...
start "Lifting Life User App (Port 8080)" cmd /k "cd tp1 && flutter run -d chrome --web-port 8080"

echo.
echo ========================================================
echo All services launched!
echo - Admin Portal:  http://localhost:3000
echo - User Website:  http://localhost:8080
echo - Backend API:   http://localhost:4000/api/health
echo ========================================================
pause

