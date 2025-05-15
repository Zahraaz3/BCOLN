import { createHelia } from 'helia'
import { json } from '@helia/json'
import express from "express"
import cors from "cors"
import { CID } from 'multiformats/cid'
const app = express()

app.use(cors());
app.use(express.json());
let helia 
let j
app.post("/add", async(req, res) => {
    try{
        
        const {name, description, base64Image} = req.body
        const cid = await j.add({name, description, base64Image})
        res.json({cid: cid.toString()})
        helia.pins.add(cid)
    }   
    catch(err){
        console.log(err)
        res.status(400).json({
            message: err.message
        })
    }
})

app.get("/:cid", async(req, res) => {
    try{
        const {cid} = req.params
        console.log(cid)
        const data = await j.get(CID.parse(cid))
        res.json(data)
    }
    catch(err){
        console.log(err)
        res.status(400).json({
            message: err.message
        })
    }
})

app.listen(8000, async () => {

    helia = await createHelia()
    await helia.start()
    j = json(helia)
    console.log("IPFS backend is listening on PORT 8000")
})

