module.exports = {
  apps: [
    {
      name: 'Ubin Fabric API - MAS',
      script: '../app.js',
      args: 'masgsgsg',
      env: { PORT: 8080, GOPATH: process.env.HOME + '/go' },
      error_file: '../logs/err-mas.log',
      out_file: '../logs/out-mas.log',
      log_date_format: 'YYYY-MM-DD HH:mm Z'
    },
    {
      name: 'Ubin Fabric API - BOFA',
      script: '../app.js',
      args: 'bofasg2x',
      env: { PORT: 8081, GOPATH: process.env.HOME + '/go' },
      error_file: '../logs/err-bofa.log',
      out_file: '../logs/out-bofa.log',
      log_date_format: 'YYYY-MM-DD HH:mm Z'
    },
    {
      name: 'Ubin Fabric API - CHASS',
      script: '../app.js',
      args: 'chassgsg',
      env: { PORT: 8082, GOPATH: process.env.HOME + '/go' },
      error_file: '../logs/err-chass.log',
      out_file: '../logs/out-chass.log',
      log_date_format: 'YYYY-MM-DD HH:mm Z'
    }
  ]
};