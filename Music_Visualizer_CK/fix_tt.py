import glob
for f in ["TableTennisScene.pde", "TableTennis3DScene.pde"]:
    try:
        content = open(f).read()
    except FileNotFoundError:
        continue
    
    # Decays
    content = content.replace('impactFlash *= 0.82;', 'impactFlash *= pow(0.82, config.TIME_SCALE);')
    content = content.replace('pointFlash  *= 0.88;', 'pointFlash *= pow(0.88, config.TIME_SCALE);')
    content = content.replace('beatGlow    *= 0.93;', 'beatGlow *= pow(0.93, config.TIME_SCALE);')
    content = content.replace('powerFlash  *= 0.85;', 'powerFlash *= pow(0.85, config.TIME_SCALE);')
    content = content.replace('leftLungeX  *= 0.80;', 'leftLungeX *= pow(0.80, config.TIME_SCALE);')
    content = content.replace('rightLungeX *= 0.80;', 'rightLungeX *= pow(0.80, config.TIME_SCALE);')
    content = content.replace('ballVX *= DRAG;', 'ballVX *= pow(DRAG, config.TIME_SCALE);')
    content = content.replace('ballVZ *= DRAG;', 'ballVZ *= pow(DRAG, config.TIME_SCALE);')
    
    # Paddle interpolation
    content = content.replace('leftPaddleY  += (leftTargetY  - leftPaddleY)  * PADDLE_SPEED;', 'leftPaddleY  += (leftTargetY  - leftPaddleY)  * (1.0 - pow(1.0 - PADDLE_SPEED, config.TIME_SCALE));')
    content = content.replace('rightPaddleY += (rightTargetY - rightPaddleY) * PADDLE_SPEED;', 'rightPaddleY += (rightTargetY - rightPaddleY) * (1.0 - pow(1.0 - PADDLE_SPEED, config.TIME_SCALE));')
    content = content.replace('leftPaddleX  += (leftTargetX  - leftPaddleX)  * PADDLE_X_SPEED;', 'leftPaddleX  += (leftTargetX  - leftPaddleX)  * (1.0 - pow(1.0 - PADDLE_X_SPEED, config.TIME_SCALE));')
    content = content.replace('rightPaddleX += (rightTargetX - rightPaddleX) * PADDLE_X_SPEED;', 'rightPaddleX += (rightTargetX - rightPaddleX) * (1.0 - pow(1.0 - PADDLE_X_SPEED, config.TIME_SCALE));')
    content = content.replace('leftPaddleZ  += (leftTargetZ  - leftPaddleZ)  * PADDLE_X_SPEED;', 'leftPaddleZ  += (leftTargetZ  - leftPaddleZ)  * (1.0 - pow(1.0 - PADDLE_X_SPEED, config.TIME_SCALE));')
    content = content.replace('rightPaddleZ += (rightTargetZ - rightPaddleZ) * PADDLE_X_SPEED;', 'rightPaddleZ += (rightTargetZ - rightPaddleZ) * (1.0 - pow(1.0 - PADDLE_X_SPEED, config.TIME_SCALE));')

    # Physics
    content = content.replace('ballVY += gravity;', 'ballVY += gravity * config.TIME_SCALE;')
    content = content.replace('ballY  += ballVY;', 'ballY  += ballVY * config.TIME_SCALE;')
    content = content.replace('ballVY += spin * abs(ballVX) * magnusStrength;', 'ballVY += spin * abs(ballVX) * magnusStrength * config.TIME_SCALE;')
    content = content.replace('ballVX += magnusX;', 'ballVX += magnusX * config.TIME_SCALE;')
    content = content.replace('ballVY += magnusY;', 'ballVY += magnusY * config.TIME_SCALE;')
    content = content.replace('ballX  += ballVX;', 'ballX  += ballVX * config.TIME_SCALE;')
    content = content.replace('ballZ  += ballVZ;', 'ballZ  += ballVZ * config.TIME_SCALE;')
    
    # 3D specific camera/board tilts
    content = content.replace('boardRotationY += (targetBoardRY - boardRotationY) * 0.1;', 'boardRotationY += (targetBoardRY - boardRotationY) * (1.0 - pow(1.0 - 0.1, config.TIME_SCALE));')
    content = content.replace('camAngle += camSpeed;', 'camAngle += camSpeed * config.TIME_SCALE;')
    content = content.replace('camRadius += (targetRadius - camRadius) * 0.05;', 'camRadius += (targetRadius - camRadius) * (1.0 - pow(1.0 - 0.05, config.TIME_SCALE));')

    open(f, 'w').write(content)
