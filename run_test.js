const http = require('http');
http.get('http://localhost:8080/', res => {
  let b=''; res.on('data',d=>b+=d); res.on('end',()=> {
    if (b.trim()==='Hello World.') { console.log('OK'); process.exit(0); }
    console.error('BAD:',b); process.exit(2);
  });
}).on('error', e => { console.error('ERR',e.message); process.exit(3); });
